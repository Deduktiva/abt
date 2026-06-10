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
    !used_in_invoices? && !used_in_delivery_notes?
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

  def normalize_invoice_email_auto_to
    self.invoice_email_auto_to = invoice_email_auto_to.to_s.strip if invoice_email_auto_to
  end

  def check_if_used
    if used_in_invoices?
      errors.add(:base, "Cannot delete customer that has been used in invoices")
      throw :abort
    elsif used_in_delivery_notes?
      errors.add(:base, "Cannot delete customer that has been used in delivery notes")
      throw :abort
    end
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
