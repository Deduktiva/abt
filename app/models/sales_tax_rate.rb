class SalesTaxRate < ActiveRecord::Base
  belongs_to :sales_tax_customer_class
  belongs_to :sales_tax_product_class

  validates :rate, :presence => true, :inclusion => 0..100
  validates :sales_tax_customer_class, :sales_tax_product_class, :presence => true
end
