class SalesTaxProductClass < ApplicationRecord
  has_many :sales_tax_rates, :dependent => :restrict_with_exception

  validates :name, :indicator_code, :presence => true
  validates :indicator_code, :uniqueness => true
end
