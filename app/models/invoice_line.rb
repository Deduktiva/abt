class InvoiceLine < ApplicationRecord
  TYPE_OPTIONS = {
    'Text' => 'text',
    'Item' => 'item',
    'Subheading' => 'subheading',
    'Plaintext' => 'plain'
  }.freeze

  validates :title, presence: true
  validates :type, presence: true, inclusion: TYPE_OPTIONS.values
  validates :rate, presence: true, if: :is_item
  validates :quantity, presence: true, if: :is_item

  belongs_to :invoice
  belongs_to :sales_tax_product_class, :optional => true

  def self.inheritance_column
    'type_'
  end

  before_save :clear_non_item_fields
  before_save :calculate_amount

  def calculate_amount
    if is_item
      self[:amount] = self[:rate] * self[:quantity]
    else
      self[:amount] = 0
    end
  end

private
  def is_item
    self[:type] == 'item'
  end

  def clear_non_item_fields
    unless is_item
      self[:rate] = nil
      self[:quantity] = nil
      self[:sales_tax_product_class_id] = nil
      self[:amount] = nil
    end
  end
end
