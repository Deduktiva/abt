class Product < ActiveRecord::Base
  attr_accessible :description, :rate, :sales_tax_product_class_id, :title
  belongs_to :sales_tax_product_class
  has_many :sales_tax_rates, :through => :sales_tax_product_class
end
