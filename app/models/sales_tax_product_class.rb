class SalesTaxProductClass < ApplicationRecord
  has_many :sales_tax_rates
  has_many :products
  has_many :invoice_tax_classes
  has_many :invoice_lines
  has_many :offer_versions

  validates :name, :indicator_code, presence: true, uniqueness: true

  before_save :unset_other_defaults, if: -> { is_default? && is_default_changed? }
  before_destroy :check_if_used

  def self.default
    find_by(is_default: true)
  end

  def can_be_deleted?
    deletion_error.nil?
  end

  private

  # Single source for both the UI gate (can_be_deleted?) and the destroy guard.
  def deletion_error
    return "Cannot delete the default product tax class" if is_default?
    return unless (blocker = deletion_blocker)
    "Cannot delete product tax class that is used in #{blocker}"
  end

  # Every association is checked because only offer_versions has a database
  # foreign key; nothing else would stop a delete from leaving dangling
  # references on published invoices.
  def deletion_blocker
    return "tax rates" if sales_tax_rates.exists?
    return "products" if products.exists?
    return "invoices" if invoice_tax_classes.exists? || invoice_lines.exists?
    "offers" if offer_versions.exists?
  end

  def check_if_used
    return unless (error = deletion_error)
    errors.add(:base, error)
    throw :abort
  end

  def unset_other_defaults
    self.class.where(is_default: true).where.not(id: id).update_all(is_default: false)
  end
end
