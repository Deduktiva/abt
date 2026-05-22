class User < ApplicationRecord
  USERNAME_FORMAT = /\A[a-z0-9_-]{3,32}\z/

  has_many :identities, class_name: "UserIdentity", dependent: :destroy
  has_many :sessions, class_name: "UserSession", dependent: :destroy
  has_many :webauthn_credentials, dependent: :destroy
  has_many :created_invites, class_name: "UserInvite", foreign_key: :created_by_user_id, dependent: :nullify
  belongs_to :blocked_by_user, class_name: "User", optional: true

  before_validation :ensure_webauthn_id

  validates :username, presence: true, uniqueness: true, format: { with: USERNAME_FORMAT }
  validates :full_name, presence: true
  validates :webauthn_id, presence: true, uniqueness: true

  scope :active, -> { where(blocked_at: nil) }
  scope :blocked, -> { where.not(blocked_at: nil) }

  def to_param
    username
  end

  def blocked?
    blocked_at.present?
  end

  def active?
    !blocked?
  end

  # Total number of independent sign-in methods linked to this user. Used to
  # block removal of the user's last credential (which would lock them out).
  def sign_in_methods_count
    identities.count + webauthn_credentials.count
  end

  def block!(by:, reason:, audit_request: nil, event_type: "block")
    return if blocked?
    transaction do
      update!(blocked_at: Time.current, blocked_reason: reason, blocked_by_user: by)
      sessions.active.each { |s| s.terminate!(reason: "blocked") }
      AuditEvent.record!(event_type: event_type, subject: self, actor: by,
                         request: audit_request, metadata: { reason: reason })
    end
  end

  def unblock!(by:, audit_request: nil)
    return unless blocked?
    transaction do
      update!(blocked_at: nil, blocked_reason: nil, blocked_by_user: nil)
      AuditEvent.record!(event_type: "unblock", subject: self, actor: by, request: audit_request)
    end
  end

  private

  def ensure_webauthn_id
    self.webauthn_id ||= SecureRandom.uuid
  end
end
