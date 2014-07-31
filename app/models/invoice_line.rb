class InvoiceLine < ActiveRecord::Base
  validates :title, presence: true
  validates :type, presence: true, inclusion: %w(item title plain text)
  validates :rate, presence: true, if: :is_item
  validates :quantity, presence: true, if: :is_item

  attr_readonly :invoice_id
  belongs_to :invoice
  belongs_to :sales_tax_product_class

  def self.inheritance_column
    'type_'
  end

  def render_xml_item

  end
end
