class User < ApplicationRecord
  USERNAME_FORMAT = /\A[\p{L}\p{N}][\p{L}\p{N}_\-.]*\z/

  has_many :emails, class_name: "UserEmail", dependent: :destroy
  has_many :credentials, class_name: "UserCredential", dependent: :destroy
  has_many :sessions, class_name: "UserSession", dependent: :destroy
  has_many :audit_events_as_subject, class_name: "UserAuditEvent",
           foreign_key: :user_id, dependent: :nullify
  has_many :audit_events_as_actor, class_name: "UserAuditEvent",
           foreign_key: :actor_user_id, dependent: :nullify

  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships

  belongs_to :blocked_by_user, class_name: "User", optional: true

  attribute :webauthn_id, default: -> { WebAuthn.generate_user_id }

  validates :username, presence: true, uniqueness: { case_sensitive: false },
            format: { with: USERNAME_FORMAT },
            length: { in: 2..40 }
  validates :full_name, presence: true, length: { maximum: 120 }
  validates :webauthn_id, presence: true

  normalizes :username, with: ->(v) { v.strip.downcase }

  after_create_commit :auto_promote_first_user
  after_create_commit :join_default_team

  scope :active, -> { where(blocked_at: nil) }
  scope :blocked, -> { where.not(blocked_at: nil) }

  # Memoized per User instance. Fine for the request/response cycle (each
  # request rebuilds current_user). If a long-running job ever reuses the
  # same User object across permission mutations, call `user.reload` (or
  # rebuild it) to get fresh permissions; this method does not invalidate
  # on group/group_permission/group_membership changes.
  def permissions
    @permissions ||= GroupPermission
                      .joins(group: :group_memberships)
                      .where(group_memberships: { user_id: id })
                      .distinct
                      .pluck(:permission)
                      .to_set
  end

  def permission?(key)
    permissions.include?(key)
  end

  # Same per-instance memoization caveat as #permissions — reload the user
  # if you mutate group memberships and need to re-check on the same object.
  def bypass_team_scoping?
    return @bypass_team_scoping if defined?(@bypass_team_scoping)
    @bypass_team_scoping = groups.where(bypass_team_scoping: true).exists?
  end

  def visible_team_ids
    if bypass_team_scoping?
      Team.pluck(:id)
    else
      team_ids
    end
  end

  def blocked?
    blocked_at.present?
  end

  def confirmed_emails
    emails.where.not(confirmed_at: nil)
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

  private

  def auto_promote_first_user
    return unless User.count == 1
    admin = Group.admin
    return unless admin
    GroupMembership.find_or_create_by!(group: admin, user: self)
  end

  def join_default_team
    default_team = Team.default
    return unless default_team
    TeamMembership.find_or_create_by!(team: default_team, user: self)
  end
end
