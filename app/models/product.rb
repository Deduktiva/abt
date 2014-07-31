class Product < ActiveRecord::Base
  belongs_to :sales_tax_product_class
  has_many :sales_tax_rates, :through => :sales_tax_product_class
end
