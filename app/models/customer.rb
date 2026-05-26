class Customer < ApplicationRecord
  include TeamOwned

  MATCHCODE_FORMAT = /\A\S{2,}\z/

  validates :matchcode, presence: true, uniqueness: { case_sensitive: false },
            format: { with: MATCHCODE_FORMAT }
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

  # Human-readable labels for the invoice_email_auto_contact_mode values.
  # Single source of truth: customer form select + customer show page both
  # read from here. Order matters: the form select uses it positionally.
  INVOICE_EMAIL_AUTO_CONTACT_MODE_LABELS = {
    "replace_contacts" => "Only auto address (ignore contacts)",
    "cc_contacts"      => "Auto address in To, contacts in CC"
  }.freeze

  def invoice_email_auto_contact_mode_label
    INVOICE_EMAIL_AUTO_CONTACT_MODE_LABELS[invoice_email_auto_contact_mode]
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
