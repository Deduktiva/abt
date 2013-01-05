class SalesTaxRate < ActiveRecord::Base
  attr_accessible :rate, :sales_tax_customer_class_id, :sales_tax_product_class_id
  belongs_to :sales_tax_customer_class
  belongs_to :sales_tax_product_class

  validates :rate, :presence => true, :inclusion => 0..100
  validates :sales_tax_customer_class, :sales_tax_product_class, :presence => true
end
