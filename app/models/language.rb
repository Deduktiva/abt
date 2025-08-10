class Language < ApplicationRecord
  validates :iso_code, presence: true, uniqueness: true, length: { is: 2 }
  validates :title, presence: true

  has_many :customers, dependent: :restrict_with_error
end
