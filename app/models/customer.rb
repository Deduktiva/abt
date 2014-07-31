class Customer < ActiveRecord::Base
  validates :matchcode, :presence => true
  validates :name, :presence => true

  belongs_to :sales_tax_customer_class
  has_many :sales_tax_rates, :through => :sales_tax_customer_class
  has_many :invoices
end
