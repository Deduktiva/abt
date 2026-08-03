class InvoiceLine < ApplicationRecord
  include LineItem

  validates :quantity, presence: true, if: :is_item?

  belongs_to :invoice
  belongs_to :sales_tax_product_class, optional: true

  # A published invoice's lines are final. Publishing saves the lines before it
  # flips the flag, so this only guards saves after the fact.
  before_save :clear_non_item_fields, unless: :invoice_published?
  before_save :calculate_amount, unless: :invoice_published?

  def calculate_amount
    if is_item? && !self[:rate].nil? && !self[:quantity].nil?
      self[:amount] = (self[:rate] * self[:quantity]).round(invoice.money_decimal_places)
    else
      self[:amount] = 0
    end
  end

private
  def invoice_published? = invoice.published?

  def clear_non_item_fields
    unless is_item?
      self[:rate] = nil
      self[:quantity] = nil
      self[:sales_tax_product_class_id] = nil
      self[:amount] = nil
    end
  end
end
