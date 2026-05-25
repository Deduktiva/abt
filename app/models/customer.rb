class Customer < ApplicationRecord
  include TeamOwned

  validates :matchcode, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :vat_id, presence: true, if: -> { sales_tax_customer_class&.vat_id_required? }

  # Set default language (English) for new customers
  before_validation :set_default_language, on: :create

  belongs_to :sales_tax_customer_class
  belongs_to :language
  has_many :sales_tax_rates, through: :sales_tax_customer_class
  has_many :invoices
  has_many :customer_contacts, dependent: :destroy

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

  def used_in_invoices?
    invoices.exists?
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

  def check_if_used
    if used_in_invoices?
      errors.add(:base, "Cannot delete customer that has been used in invoices")
      throw :abort
    end
  end

  def sync_project_teams
    Project.where(bill_to_customer_id: id).update_all(team_id: team_id, updated_at: Time.current)
  end
end
