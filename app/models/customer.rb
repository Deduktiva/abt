class Customer < ApplicationRecord
  validates :matchcode, presence: true
  validates :name, presence: true

  # Set default language (English) for new customers
  before_validation :set_default_language, on: :create

  belongs_to :sales_tax_customer_class
  belongs_to :language
  has_many :sales_tax_rates, through: :sales_tax_customer_class
  has_many :invoices

  # Scopes for filtering
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  def used_in_invoices?
    invoices.exists?
  end

  before_destroy :check_if_used

  private

  def set_default_language
    self.language ||= Language.find_by(iso_code: "en")
  end

  def check_if_used
    if used_in_invoices?
      errors.add(:base, "Cannot delete customer that has been used in invoices")
      throw :abort
    end
  end
end
