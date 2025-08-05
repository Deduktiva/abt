class CustomerContactProject < ApplicationRecord
  belongs_to :customer_contact
  belongs_to :project

  # Validate that the project belongs to the same customer as the contact
  # or that the project has no customer (reusable project)
  validate :project_customer_matches_contact_customer

  private

  def project_customer_matches_contact_customer
    return unless customer_contact && project

    if project.bill_to_customer.present? &&
       project.bill_to_customer != customer_contact.customer
      errors.add(:project, "must belong to the same customer as the contact")
    end
  end
end
