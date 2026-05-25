class CustomerContact < ApplicationRecord
  belongs_to :customer
  has_and_belongs_to_many :projects, join_table: :customer_contact_projects

  before_validation :normalize_email_and_name

  validates :name,  presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :customer_must_be_visible_to_current_user, if: :will_save_change_to_customer_id?
  validate :projects_belong_to_customer_or_unassigned
  validate :projects_must_be_visible_to_current_user

  scope :for_invoices,       -> { where(receives_invoice_emails: true) }
  scope :for_delivery_notes, -> { where(receives_delivery_note_emails: true) }
  scope :for_offers,         -> { where(receives_offer_emails: true) }

  # No projects assigned == applies to all projects of this customer.
  def applies_to_project?(project)
    projects.empty? || projects.include?(project)
  end

  def to_email_address
    addr = Mail::Address.new
    addr.address = email.to_s
    # Collapse CR/LF so a malicious contact name can't inject headers.
    addr.display_name = name.to_s.gsub(/[\r\n]+/, " ")
    addr.format
  end

  private

  def normalize_email_and_name
    self.email = email.to_s.strip if email
    self.name  = name.to_s.strip  if name
  end

  def projects_belong_to_customer_or_unassigned
    bad = projects.reject { |p| p.bill_to_customer_id.nil? || p.bill_to_customer_id == customer_id }
    errors.add(:projects, "must belong to this customer or to no customer") if bad.any?
  end

  # Mirrors ScopedThroughCustomer: skip when Current.user is nil so seeds /
  # console / jobs can build contacts freely.
  def customer_must_be_visible_to_current_user
    user = Current.user
    return if user.nil?
    return if customer_id && Customer.visible_to(user).where(id: customer_id).exists?
    errors.add(:customer_id, "must be a customer you can access")
  end

  def projects_must_be_visible_to_current_user
    user = Current.user
    return if user.nil? || projects.empty?
    visible_ids = Project.visible_to(user).where(id: projects.map(&:id)).pluck(:id).to_set
    bad = projects.reject { |p| visible_ids.include?(p.id) }
    errors.add(:projects, "must be projects you can access") if bad.any?
  end
end
