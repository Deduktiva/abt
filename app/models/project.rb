class Project < ApplicationRecord
  belongs_to :bill_to_customer, :class_name => 'Customer'

  validates :matchcode, :presence => true

  def display_name
    if description.present?
      description
    else
      matchcode
    end
  end
end
