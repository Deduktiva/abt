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

  # Returns true when this customer has a configured rule for auto-splitting
  # a scaffolded offer into milestones. When false, the edit page hides the
  # "Apply customer rule" form.
  def offer_milestone_rule_configured?
    offer_milestone_split_threshold.present? && offer_milestone_split_first_ratio.present?
  end

  # Build milestone records (NOT saved) for an offer version totalling
  # `total_amount`. Below threshold: a single "Final delivery" milestone.
  # Above threshold: an order-entry milestone at first_ratio of the total,
  # plus a final-delivery milestone for the remainder. Caller persists.
  def scaffold_offer_milestones(total_amount)
    total = BigDecimal(total_amount.to_s)
    threshold = offer_milestone_split_threshold
    ratio = offer_milestone_split_first_ratio

    if threshold && ratio && total > threshold
      first = (total * ratio).round(2)
      second = total - first
      [
        { title: "Order entry",    trigger: "on_order",      net_amount: first,  position: 0 },
        { title: "Final delivery", trigger: "on_acceptance", net_amount: second, position: 1 }
      ]
    else
      [ { title: "Final delivery", trigger: "on_acceptance", net_amount: total, position: 0 } ]
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
