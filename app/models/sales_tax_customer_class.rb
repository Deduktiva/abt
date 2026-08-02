class SalesTaxCustomerClass < ApplicationRecord
  has_many :sales_tax_rates, dependent: :restrict_with_error
  has_many :customers, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
end
