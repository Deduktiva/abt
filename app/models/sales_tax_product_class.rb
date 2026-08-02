class SalesTaxProductClass < ApplicationRecord
  # Restrict every reference: only offer_versions has a database foreign key,
  # and dangling invoice_tax_classes/invoice_lines would corrupt published
  # invoices.
  has_many :sales_tax_rates, dependent: :restrict_with_error
  has_many :products, dependent: :restrict_with_error
  has_many :invoice_tax_classes, dependent: :restrict_with_error
  has_many :invoice_lines, dependent: :restrict_with_error
  has_many :offer_versions, dependent: :restrict_with_error

  validates :name, :indicator_code, presence: true, uniqueness: true

  before_save :unset_other_defaults, if: -> { is_default? && is_default_changed? }

  def self.default
    find_by(is_default: true)
  end

  private

  def unset_other_defaults
    self.class.where(is_default: true).where.not(id: id).update_all(is_default: false)
  end
end
