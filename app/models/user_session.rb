class UserSession < ApplicationRecord
  TOKEN_BYTES = 32

  belongs_to :user

  scope :active, -> { where(terminated_at: nil) }

  def self.digest(raw_token)
    OpenSSL::HMAC.hexdigest(
      "SHA256",
      Rails.application.secret_key_base,
      raw_token.to_s
    )
  end

  def self.start!(user:, request: nil)
    raw = SecureRandom.urlsafe_base64(TOKEN_BYTES)
    record = create!(
      user: user,
      token_digest: digest(raw),
      user_agent: request&.user_agent,
      ip: request&.remote_ip,
      last_seen_at: Time.current
    )
    [record, raw]
  end

  def self.find_active_by_token(raw_token)
    return nil if raw_token.blank?
    active.find_by(token_digest: digest(raw_token))
  end

  def terminate!(reason:)
    return if terminated?
    update!(terminated_at: Time.current, terminated_reason: reason)
  end

  def terminated?
    terminated_at.present?
  end

  def active?
    !terminated?
  end
end
