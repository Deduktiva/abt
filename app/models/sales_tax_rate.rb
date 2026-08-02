class SalesTaxRate < ApplicationRecord
  belongs_to :sales_tax_customer_class
  belongs_to :sales_tax_product_class

  validates :rate, presence: true, inclusion: 0..100
  validates :sales_tax_customer_class, :sales_tax_product_class, presence: true
  validates :sales_tax_product_class_id, uniqueness: { scope: :sales_tax_customer_class_id,
                                                       message: "already has a rate for this customer class" }
end
