class InvoiceTaxClass < ApplicationRecord
  belongs_to :sales_tax_product_class
  belongs_to :invoice

  validates :net, :presence => true
  validates :rate, :presence => true

  def net=(value)
    self[:net] = value
    self[:value] = self[:net] * (self[:rate]/100.0)
    self[:total] = self[:net] + self[:value]
  end
end
