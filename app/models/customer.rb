class Customer < ApplicationRecord
  validates :matchcode, :presence => true
  validates :name, :presence => true

  belongs_to :sales_tax_customer_class
  has_many :sales_tax_rates, :through => :sales_tax_customer_class
  has_many :invoices

  # Check if this customer has been used in any invoices
  def used_in_invoices?
    invoices.exists?
  end

  # Prevent deletion if customer has been used
  before_destroy :check_if_used

  private

  def check_if_used
    if used_in_invoices?
      errors.add(:base, "Cannot delete customer that has been used in invoices")
      throw :abort
    end
  end
end
