class SalesTaxCustomerClass < ActiveRecord::Base
  attr_accessible :invoice_note, :name
  has_many :sales_tax_rates

  validates :name, :presence => true
end
