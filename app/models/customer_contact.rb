class CustomerContact < ApplicationRecord
  belongs_to :customer
  has_and_belongs_to_many :projects, join_table: :customer_contact_projects

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :customer_id, message: "already exists for this customer" }

  # Scopes for filtering
  scope :receiving_invoices, -> { where(receives_invoices: true) }
end