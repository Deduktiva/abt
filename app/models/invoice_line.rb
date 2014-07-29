class InvoiceLine < ActiveRecord::Base
  attr_accessible :amount, :description, :quantity, :rate, :title, :type,
                  :sales_tax_product_class_id, :sales_tax_indicator_code, :sales_tax_name, :sales_tax_rate
  attr_readonly :invoice_id
  belongs_to :invoice
  belongs_to :sales_tax_product_class

  def self.inheritance_column
    'type_'
  end

  def render_xml_item

  end
end
