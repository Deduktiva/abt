class Customer < ApplicationRecord
  include TeamOwned

  validates :matchcode, presence: true, uniqueness: { case_sensitive: false }
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

  # When a customer moves to a different team, cascade the change to every
  # project that bills to this customer. Project#team_must_match_customer
  # otherwise leaves the projects in an inconsistent state (immediately
  # unsaveable, and invisible to members of the new team because their
  # team_id still points at the old one). update_all is fine here:
  # team_must_match_customer would pass (we're moving INTO match), and the
  # write is authorized by the customer-side change.
  after_update :sync_project_teams, if: :saved_change_to_team_id?

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

  def sync_project_teams
    Project.where(bill_to_customer_id: id).update_all(team_id: team_id, updated_at: Time.current)
  end
end
