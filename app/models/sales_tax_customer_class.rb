class SalesTaxCustomerClass < ActiveRecord::Base
  attr_accessible :invoice_note, :name
  has_many :sales_tax_rates, :dependent => :restrict_with_exception
  has_many :customers, :dependent => :restrict_with_exception

  validates :name, :presence => true
end
