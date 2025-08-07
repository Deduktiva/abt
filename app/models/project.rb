class Project < ApplicationRecord
  belongs_to :bill_to_customer, :class_name => 'Customer', :optional => true
  has_many :invoices

  validates :matchcode, :presence => true

  # Scopes for filtering
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Check if this project has been used in any invoices
  def used_in_invoices?
    invoices.exists?
  end

  # Prevent deletion if project has been used
  before_destroy :check_if_used

  # Allow deactivation instead of deletion for used projects
  def can_be_deleted?
    !used_in_invoices?
  end

  def can_be_deactivated?
    used_in_invoices?
  end

  def display_name
    if description.present?
      description
    else
      matchcode
    end
  end

  private

  def check_if_used
    if used_in_invoices?
      errors.add(:base, "Cannot delete project that has been used in invoices")
      throw :abort
    end
  end
end
