class UserInvite < ApplicationRecord
  DEFAULT_TTL = 24.hours

  belongs_to :created_by_user, class_name: "User", optional: true
  belongs_to :consumed_by_user, class_name: "User", optional: true

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :assign_defaults, on: :create

  scope :pending, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def consumed?
    consumed_at.present?
  end

  def consumable?
    !consumed? && !expired?
  end

  def consume!(user:)
    raise ActiveRecord::RecordInvalid.new(self) unless consumable?
    update!(consumed_at: Time.current, consumed_by_user: user)
  end

  private

  def assign_defaults
    self.token ||= SecureRandom.urlsafe_base64(32)
    self.expires_at ||= DEFAULT_TTL.from_now
  end
end
