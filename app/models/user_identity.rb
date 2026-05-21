class UserIdentity < ApplicationRecord
  belongs_to :user

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }

  def self.find_or_initialize_from_auth(auth)
    identity = find_or_initialize_by(provider: auth.provider.to_s, uid: auth.uid.to_s)
    identity.nickname = auth.info&.nickname
    identity.email = auth.info&.email
    identity.raw_info = auth.info&.to_h || {}
    identity
  end
end
