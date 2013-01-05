class SalesTaxProductClass < ActiveRecord::Base
  attr_accessible :indicator_code, :name
  has_many :sales_tax_rates, :dependent => :restrict

  validates :name, :indicator_code, :presence => true
  validates :indicator_code, :uniqueness => true
end
