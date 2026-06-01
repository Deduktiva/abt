class InvoiceLine < ApplicationRecord
  include LineItem

  validates :quantity, presence: true, if: :is_item?

  belongs_to :invoice
  belongs_to :sales_tax_product_class, optional: true

  before_save :clear_non_item_fields
  before_save :calculate_amount

  def calculate_amount
    if is_item? && !self[:rate].nil? && !self[:quantity].nil?
      self[:amount] = self[:rate] * self[:quantity]
    else
      self[:amount] = 0
    end
  end

private
  def clear_non_item_fields
    unless is_item?
      self[:rate] = nil
      self[:quantity] = nil
      self[:sales_tax_product_class_id] = nil
      self[:amount] = nil
    end
  end
end
