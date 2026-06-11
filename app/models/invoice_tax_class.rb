class InvoiceTaxClass < ApplicationRecord
  belongs_to :sales_tax_product_class
  belongs_to :invoice

  validates :net, presence: true
  validates :rate, presence: true

  def net=(value)
    self[:net] = value
    self[:value] = (self[:net] * self[:rate] / 100).round(invoice.money_decimal_places)
    self[:total] = self[:net] + self[:value]
  end
end
