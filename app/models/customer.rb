class Customer < ApplicationRecord
  validates :matchcode, :presence => true
  validates :name, :presence => true

  # Set default language (English) for new customers
  before_validation :set_default_language, on: :create

  belongs_to :sales_tax_customer_class
  belongs_to :language
  has_many :sales_tax_rates, :through => :sales_tax_customer_class
  has_many :invoices
  has_many :customer_contacts, dependent: :destroy

  # Scopes for filtering
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Check if this customer has been used in any invoices
  def used_in_invoices?
    invoices.exists?
  end

  # Prevent deletion if customer has been used
  before_destroy :check_if_used

  # Allow deactivation instead of deletion for used customers
  def can_be_deleted?
    !used_in_invoices?
  end

  def can_be_deactivated?
    used_in_invoices?
  end

  private

  def set_default_language
    self.language ||= Language.find_by(iso_code: 'en')
  end

  def check_if_used
    if used_in_invoices?
      errors.add(:base, "Cannot delete customer that has been used in invoices")
      throw :abort
    end
  end
end
