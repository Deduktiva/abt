class UserCredential < ApplicationRecord
  belongs_to :user

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :nickname, presence: true, length: { maximum: 80 }
  validates :sign_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def touch_used!(new_sign_count)
    update!(sign_count: new_sign_count, last_used_at: Time.current)
  end
end
