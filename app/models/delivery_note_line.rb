class DeliveryNoteLine < ApplicationRecord
  TYPE_OPTIONS = {
    'Text' => 'text',
    'Item' => 'item',
    'Subheading' => 'subheading',
    'Plaintext' => 'plain'
  }.freeze

  validates :title, presence: true
  validates :type, presence: true, inclusion: TYPE_OPTIONS.values
  validates :quantity, presence: true, if: :is_item?

  belongs_to :delivery_note

  def self.inheritance_column
    'type_'
  end

  def is_item?
    self[:type] == 'item'
  end
end
