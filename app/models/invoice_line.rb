class InvoiceLine < ApplicationRecord
  validates :title, presence: true
  validates :type, presence: true, inclusion: %w(item subheading plain text)
  validates :rate, presence: true, if: :is_item
  validates :quantity, presence: true, if: :is_item

  belongs_to :invoice
  belongs_to :sales_tax_product_class

  def self.inheritance_column
    'type_'
  end

  after_validation :calculate_amount

private
  def is_item
    self[:type] == 'item'
  end

  def calculate_amount
    return unless self[:type] == 'item'
    self[:amount] = self[:rate] * self[:quantity]
  end
end
