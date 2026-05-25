class DeliveryNoteLine < ApplicationRecord
  include LineItem

  validates :quantity, presence: true, if: :is_item?

  belongs_to :delivery_note
end
