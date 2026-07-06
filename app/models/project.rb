class Project < ApplicationRecord
  include TeamOwned
  include HasMatchcode

  belongs_to :bill_to_customer, class_name: "Customer", optional: true
  has_many :invoices
  has_many :delivery_notes
  has_many :offers

  validate :team_must_match_customer

  # Scopes for filtering
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Check if this project has been used in any invoices
  def used_in_invoices?
    invoices.exists?
  end

  def used_in_delivery_notes?
    delivery_notes.exists?
  end

  def used_in_offers?
    offers.exists?
  end

  # Prevent deletion if project has been used
  before_destroy :check_if_used

  # Allow deactivation instead of deletion for used projects
  def can_be_deleted?
    deletion_blocker.nil?
  end

  def display_name
    if description.present?
      description
    else
      matchcode
    end
  end

  private

  # The document type (if any) that blocks deletion. Single source for both the
  # UI gate (can_be_deleted?) and the destroy guard's error message.
  def deletion_blocker
    return "invoices" if used_in_invoices?
    return "delivery notes" if used_in_delivery_notes?
    "offers" if used_in_offers?
  end

  def check_if_used
    return unless (blocker = deletion_blocker)
    errors.add(:base, "Cannot delete project that has been used in #{blocker}")
    throw :abort
  end

  # Reusable projects (no bill_to_customer) are free to pick any team.
  # Projects with a customer must share that customer's team.
  def team_must_match_customer
    return if bill_to_customer_id.blank?
    return unless team_id && bill_to_customer && bill_to_customer.team_id
    if team_id != bill_to_customer.team_id
      errors.add(:team_id, "must match the team of the bill-to customer (#{bill_to_customer.team&.name})")
    end
  end
end
