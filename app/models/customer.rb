class Customer < ApplicationRecord
  include TeamOwned
  include HasMatchcode

  validates :name, presence: true
  validates :vat_id, presence: true, if: -> { sales_tax_customer_class&.vat_id_required? }
  validates :country_iso2, presence: true, inclusion: { in: ISO3166::Country.codes, message: "must be a valid country" }
  validates :invoice_email_auto_to, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  # Set default language (English) for new customers
  before_validation :set_default_language, on: :create
  before_validation :normalize_invoice_email_auto_to

  belongs_to :sales_tax_customer_class
  belongs_to :language
  has_many :sales_tax_rates, through: :sales_tax_customer_class
  has_many :invoices
  has_many :delivery_notes
  has_many :customer_contacts, dependent: :destroy
  has_many :vat_verifications, class_name: "CustomerVatVerification", dependent: :destroy

  before_save :normalise_vat_id
  before_save :clear_vat_id_verified_at_if_vat_id_changed

  enum :invoice_email_auto_contact_mode, {
    replace_contacts: "replace_contacts",
    cc_contacts: "cc_contacts"
  }

  enum :offer_email_auto_contact_mode, {
    replace_contacts: "replace_contacts",
    cc_contacts: "cc_contacts"
  }, prefix: :offer

  # Human-readable labels for the *_email_auto_contact_mode values.
  # Both document types use the same semantic options, so we share one map.
  # Single source of truth: customer form selects + customer show page read
  # from here. Order matters: the form select uses it positionally.
  EMAIL_AUTO_CONTACT_MODE_LABELS = {
    "replace_contacts" => "Only auto address (ignore contacts)",
    "cc_contacts"      => "Auto address in To, contacts in CC"
  }.freeze
  INVOICE_EMAIL_AUTO_CONTACT_MODE_LABELS = EMAIL_AUTO_CONTACT_MODE_LABELS
  OFFER_EMAIL_AUTO_CONTACT_MODE_LABELS   = EMAIL_AUTO_CONTACT_MODE_LABELS

  def invoice_email_auto_contact_mode_label
    EMAIL_AUTO_CONTACT_MODE_LABELS[invoice_email_auto_contact_mode]
  end

  def offer_email_auto_contact_mode_label
    EMAIL_AUTO_CONTACT_MODE_LABELS[offer_email_auto_contact_mode]
  end

  # Scopes for filtering
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :vat_verification_required, -> {
    active
      .where.not(vat_id: [ nil, "" ])
      .joins(:sales_tax_customer_class)
      .where(sales_tax_customer_classes: { vat_id_required: true })
  }

  def used_in_invoices?
    invoices.exists?
  end

  def used_in_delivery_notes?
    delivery_notes.exists?
  end

  def can_be_deleted?
    deletion_blocker.nil?
  end

  def latest_vat_verification
    vat_verifications.latest_first.first
  end

  # VIES rejects any separators or lowercase letters in the VAT ID.
  def self.normalise_vat_id(value)
    value.to_s.upcase.gsub(/[\s.\-]/, "")
  end

  # The most recent verification, only if it was taken against the customer's
  # current vat_id. Returns nil when the vat_id has changed since the last
  # verification — the UI then treats the customer as "Not verified" rather
  # than rendering a stale "Invalid per VIES" / "verified" state.
  def current_vat_verification
    verification = latest_vat_verification
    verification if verification && verification.vat_id == self.class.normalise_vat_id(vat_id)
  end

  def contacts_for_invoice(invoice)
    customer_contacts.for_invoices.select { |c| c.applies_to_project?(invoice.project) }
  end

  def contacts_for_delivery_note(delivery_note)
    customer_contacts.for_delivery_notes.select { |c| c.applies_to_project?(delivery_note.project) }
  end

  def contacts_for_offer(offer)
    customer_contacts.for_offers.select { |c| c.applies_to_project?(offer.project) }
  end

  # Returns true when this customer has a usable rule for auto-scaffolding
  # offer milestones. Requires a threshold and at least one parsed template
  # in at least one of the two template lists.
  def offer_milestone_rule_configured?
    offer_milestone_split_threshold.present? &&
      (offer_milestone_templates_above.to_s.strip.present? ||
       offer_milestone_templates_below.to_s.strip.present?)
  end

  # Build milestone records (NOT saved) for an offer version totalling
  # `total_amount`. Picks the template list by comparing the total against
  # the threshold; parses the chosen list as `Title|trigger|ratio` lines;
  # distributes total_amount across the templates by ratio, with the last
  # row absorbing the rounding remainder so the amounts sum to the total.
  #
  # Falls back to a single placeholder "Milestone" line if no templates
  # parse — the admin then edits the row.
  def scaffold_offer_milestones(total_amount)
    total = BigDecimal(total_amount.to_s)
    raw = if offer_milestone_split_threshold && total > offer_milestone_split_threshold
      offer_milestone_templates_above
    else
      offer_milestone_templates_below
    end
    templates = parse_offer_milestone_templates(raw)
    return [ { title: "Milestone", trigger: "on_acceptance", net_amount: total, position: 0 } ] if templates.empty?

    amounts = templates.map { |t| (total * t[:ratio]).round(2) }
    amounts[-1] = total - amounts[0..-2].sum
    templates.each_with_index.map do |t, i|
      { title: t[:title], trigger: t[:trigger], net_amount: amounts[i], position: i }
    end
  end

  before_destroy :check_if_used

  # When a customer moves to a different team, cascade the change to every
  # project that bills to this customer. Project#team_must_match_customer
  # otherwise leaves the projects in an inconsistent state (immediately
  # unsaveable, and invisible to members of the new team because their
  # team_id still points at the old one). update_all is fine here:
  # team_must_match_customer would pass (we're moving INTO match), and the
  # write is authorized by the customer-side change.
  after_update :sync_project_teams, if: :saved_change_to_team_id?

  private

  # "Title|trigger|ratio" per non-blank line. Robust to whitespace; silently
  # skips malformed lines.
  def parse_offer_milestone_templates(raw)
    return [] if raw.blank?
    valid_triggers = OfferMilestone.triggers.keys.to_set
    raw.each_line.filter_map do |line|
      parts = line.strip.split("|").map(&:strip)
      next if parts.size < 3 || parts.any?(&:empty?)
      next unless valid_triggers.include?(parts[1])
      ratio = Float(parts[2]) rescue nil
      next if ratio.nil? || ratio <= 0
      { title: parts[0], trigger: parts[1], ratio: BigDecimal(ratio.to_s) }
    end
  end

  def set_default_language
    self.language ||= Language.find_by(iso_code: "en")
  end

  def normalize_invoice_email_auto_to
    self.invoice_email_auto_to = invoice_email_auto_to.to_s.strip if invoice_email_auto_to
  end

  # The document type (if any) that blocks deletion. Single source for both the
  # UI gate (can_be_deleted?) and the destroy guard's error message.
  def deletion_blocker
    return "invoices" if used_in_invoices?
    "delivery notes" if used_in_delivery_notes?
  end

  def check_if_used
    return unless (blocker = deletion_blocker)
    errors.add(:base, "Cannot delete customer that has been used in #{blocker}")
    throw :abort
  end

  def sync_project_teams
    Project.where(bill_to_customer_id: id).update_all(team_id: team_id, updated_at: Time.current)
  end

  def normalise_vat_id
    self.vat_id = self.class.normalise_vat_id(vat_id) if vat_id.present?
  end

  def clear_vat_id_verified_at_if_vat_id_changed
    self.vat_id_verified_at = nil if will_save_change_to_vat_id?
  end
end
