class UserSession < ApplicationRecord
  EXPIRY = 30.days

  belongs_to :user
  belongs_to :terminated_by_user, class_name: 'User', optional: true

  scope :active, -> {
    where(terminated_at: nil).where('last_seen_at > ?', EXPIRY.ago)
  }

  def self.create_for!(user:, request:)
    plaintext = SecureRandom.urlsafe_base64(32)
    record = create!(
      user: user,
      token_digest: digest_token(plaintext),
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent.to_s.first(500),
      last_seen_at: Time.current
    )
    [record, plaintext]
  end

  def self.authenticate(plaintext)
    return nil if plaintext.blank?
    active.where(token_digest: digest_token(plaintext)).first
  end

  def self.digest_token(plaintext)
    Digest::SHA256.hexdigest(plaintext)
  end

  def active?
    terminated_at.nil? && last_seen_at > EXPIRY.ago
  end

  def terminate!(reason:, actor:, request: nil)
    return if terminated_at.present?

    update!(
      terminated_at: Time.current,
      termination_reason: reason,
      terminated_by_user: actor
    )
    UserAuditEvent.record!(
      action: 'session_terminated',
      user: user,
      actor: actor,
      request: request,
      metadata: {
        reason: reason,
        session_id: id,
        ip_address: ip_address,
        username: user&.username
      }.compact
    )
  end

  def touch_seen!(request)
    update_columns(
      last_seen_at: Time.current,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent.to_s.first(500)
    )
  end
end
