class SalesTaxCustomerClass < ActiveRecord::Base
  attr_accessible :invoice_note, :name
  has_many :sales_tax_rates, :dependent => :restrict
  has_many :customers, :dependent => :restrict

  validates :name, :presence => true
end
