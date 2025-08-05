class CustomerContact < ApplicationRecord
  belongs_to :customer
  has_many :customer_contact_projects, dependent: :destroy
  has_many :projects, through: :customer_contact_projects

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Document type flags for email delivery
  # =====================================
  # Currently only invoices are supported via the 'receives_invoices' boolean column.
  #
  # When adding new document types (quotes, statements, etc.), follow this pattern:
  # 1. Add migration: add_column :customer_contacts, :receives_quotes, :boolean, default: false
  # 2. Add method: receives_quotes_for_project?(project) following same logic as below
  # 3. Update mailers to check new flag: contact.receives_quotes_for_project?(document.project)
  # 4. Update UI forms and views to show/edit new flag
  # 5. Update tests to cover new document type scenarios
  #
  # Example implementation for quotes:
  # def receives_quotes_for_project?(project)
  #   return false unless receives_quotes?
  #   return true if projects.empty?
  #   projects.include?(project)
  # end

  # Check if this contact should receive invoices for a specific project
  def receives_invoices_for_project?(project)
    return false unless receives_invoices?

    # If no projects are associated, receives all invoices
    return true if projects.empty?

    # If projects are associated, only receives invoices for those projects
    projects.include?(project)
  end
end
