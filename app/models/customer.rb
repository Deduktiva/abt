class Customer < ApplicationRecord
  validates :matchcode, :presence => true
  validates :name, :presence => true

  belongs_to :sales_tax_customer_class
  has_many :sales_tax_rates, :through => :sales_tax_customer_class
  has_many :invoices
  has_many :customer_contacts, dependent: :destroy

  # Scopes for filtering
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Check if this customer has been used in any invoices
  def used_in_invoices?
    invoices.exists?
  end

  # Prevent deletion if customer has been used
  before_destroy :check_if_used

  # Allow deactivation instead of deletion for used customers
  def can_be_deleted?
    !used_in_invoices?
  end

  def can_be_deactivated?
    used_in_invoices?
  end

  # Helper method to check if customer has email contacts for invoices
  def has_invoice_email?
    invoice_email_auto_enabled || customer_contacts.receiving_invoices.any?
  end

  private

  def check_if_used
    if used_in_invoices?
      errors.add(:base, "Cannot delete customer that has been used in invoices")
      throw :abort
    end
  end
end
