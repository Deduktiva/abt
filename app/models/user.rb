class User < ApplicationRecord
  USERNAME_FORMAT = /\A[a-z0-9][a-z0-9_\-.]*\z/i

  has_many :emails, class_name: "UserEmail", dependent: :destroy
  has_many :credentials, class_name: "UserCredential", dependent: :destroy
  has_many :sessions, class_name: "UserSession", dependent: :destroy
  has_many :audit_events_as_subject, class_name: "UserAuditEvent",
           foreign_key: :user_id, dependent: :nullify
  has_many :audit_events_as_actor, class_name: "UserAuditEvent",
           foreign_key: :actor_user_id, dependent: :nullify

  belongs_to :blocked_by_user, class_name: "User", optional: true

  attribute :webauthn_id, default: -> { WebAuthn.generate_user_id }

  validates :username, presence: true, uniqueness: { case_sensitive: false },
            format: { with: USERNAME_FORMAT },
            length: { in: 2..40 }
  validates :full_name, presence: true, length: { maximum: 120 }
  validates :webauthn_id, presence: true

  normalizes :username, with: ->(v) { v.strip.downcase }

  scope :active, -> { where(blocked_at: nil) }
  scope :blocked, -> { where.not(blocked_at: nil) }

  def blocked?
    blocked_at.present?
  end

  def confirmed_emails
    emails.where.not(confirmed_at: nil)
  end

  def primary_email
    confirmed_emails.order(:created_at).first
  end

  def block!(reason:, actor:, request: nil)
    transaction do
      update!(
        blocked_at: Time.current,
        blocked_reason: reason,
        blocked_by_user: actor
      )
      sessions.active.find_each do |s|
        s.terminate!(reason: "user_blocked: #{reason}", actor: actor)
      end
      UserAuditEvent.record!(
        action: "blocked",
        user: self,
        actor: actor,
        request: request,
        metadata: { reason: reason, username: username }
      )
    end
  end

  def unblock!(actor:, reason: nil, request: nil)
    transaction do
      update!(blocked_at: nil, blocked_reason: nil, blocked_by_user: nil)
      UserAuditEvent.record!(
        action: "unblocked",
        user: self,
        actor: actor,
        request: request,
        metadata: { reason: reason, username: username }.compact
      )
    end
  end

  def reset_passkeys!(actor:, request: nil)
    transaction do
      credentials.destroy_all
      sessions.active.find_each do |s|
        s.terminate!(reason: "passkey_reset", actor: actor)
      end
      invite, plaintext = UserInvite.create_passkey_reset!(target_user: self, actor: actor)
      UserAuditEvent.record!(
        action: "passkey_reset",
        user: self,
        actor: actor,
        request: request,
        metadata: { username: username }
      )
      [ invite, plaintext ]
    end
  end
end
