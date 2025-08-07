class CustomerContactProject < ApplicationRecord
  belongs_to :customer_contact
  belongs_to :project
end