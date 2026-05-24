class SalesTaxProductClass < ApplicationRecord
  has_many :sales_tax_rates, :dependent => :restrict_with_exception

  validates :name, :indicator_code, :presence => true
  validates :indicator_code, :uniqueness => true

  before_save :unset_other_defaults, if: -> { is_default? && is_default_changed? }

  def self.default
    find_by(is_default: true)
  end

  private

  def unset_other_defaults
    self.class.where(is_default: true).where.not(id: id).update_all(is_default: false)
  end
end
