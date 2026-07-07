class UserInvite < ApplicationRecord
  include DigestedToken

  # Raised when consume! loses the race to another concurrent flow that
  # already claimed (or expired) the same invite.
  class AlreadyConsumed < StandardError; end

  EXPIRY = 24.hours

  PURPOSE_SIGNUP = "signup".freeze
  PURPOSE_PASSKEY_RESET = "passkey_reset".freeze
  PURPOSES = [ PURPOSE_SIGNUP, PURPOSE_PASSKEY_RESET ].freeze

  belongs_to :created_by_user, class_name: "User", optional: true
  belongs_to :target_user, class_name: "User", optional: true
  belongs_to :used_by_user, class_name: "User", optional: true

  validates :purpose, inclusion: { in: PURPOSES }
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validate :target_user_matches_purpose

  scope :usable, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  def self.create_signup!(actor:)
    plaintext, digest = generate_token
    record = create!(
      token_digest: digest,
      created_by_user: actor,
      purpose: PURPOSE_SIGNUP,
      expires_at: EXPIRY.from_now
    )
    [ record, plaintext ]
  end

  def self.create_passkey_reset!(target_user:, actor:)
    plaintext, digest = generate_token
    record = create!(
      token_digest: digest,
      created_by_user: actor,
      target_user: target_user,
      purpose: PURPOSE_PASSKEY_RESET,
      expires_at: EXPIRY.from_now
    )
    [ record, plaintext ]
  end

  def self.find_usable(plaintext)
    return nil if plaintext.blank?
    usable.where(token_digest: digest_token(plaintext)).first
  end

  # Atomically claim the invite. The conditional UPDATE re-checks the `usable`
  # predicate (unused and unexpired) at the database level, so two concurrent
  # WebAuthn flows carrying valid pending challenges for the same signup invite
  # cannot both succeed: the loser's UPDATE affects zero rows and raises,
  # rolling back its enclosing transaction (and the account it just built).
  # A plain update! here would let one invite mint several accounts under a
  # race, defeating invite-only signup's one-invite-one-account guarantee.
  def consume!(user:)
    claimed = self.class.usable.where(id: id).update_all(
      used_at: Time.current, used_by_user_id: user.id
    )
    raise AlreadyConsumed, "invite #{id} already consumed" if claimed.zero?
    reload
  end

  def signup?
    purpose == PURPOSE_SIGNUP
  end

  def passkey_reset?
    purpose == PURPOSE_PASSKEY_RESET
  end

  private

  def target_user_matches_purpose
    if passkey_reset? && target_user_id.blank?
      errors.add(:target_user, "must be present for passkey_reset invites")
    elsif signup? && target_user_id.present?
      errors.add(:target_user, "must be blank for signup invites")
    end
  end
end
