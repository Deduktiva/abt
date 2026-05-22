class WebauthnCredential < ApplicationRecord
  belongs_to :user

  validates :external_id, :public_key, presence: true
  validates :external_id, uniqueness: true

  scope :ordered, -> { order(:created_at) }

  def record_use!(new_sign_count:)
    update!(sign_count: new_sign_count, last_used_at: Time.current)
  end
end
