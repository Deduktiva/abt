class SalesTaxCustomerClass < ApplicationRecord
  has_many :sales_tax_rates
  has_many :customers

  validates :name, presence: true, uniqueness: true

  before_destroy :check_if_used

  def can_be_deleted?
    deletion_blocker.nil?
  end

  private

  # Single source for both the UI gate (can_be_deleted?) and the destroy guard.
  def deletion_blocker
    return "tax rates" if sales_tax_rates.exists?
    "customers" if customers.exists?
  end

  def check_if_used
    return unless (blocker = deletion_blocker)
    errors.add(:base, "Cannot delete customer tax class that is used in #{blocker}")
    throw :abort
  end
end
