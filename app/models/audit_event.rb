class AuditEvent < ApplicationRecord
  belongs_to :subject_user, class_name: "User", optional: true
  belongs_to :actor_user, class_name: "User", optional: true

  validates :event_type, presence: true

  self.record_timestamps = false

  EVENT_TYPES = %w[
    login login_failed logout session_terminated
    block unblock self_block
    invite_created invite_consumed invite_revoked
    user_created identity_added identity_removed
  ].freeze

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(t) { where(event_type: t) if t.present? }
  scope :for_subject, ->(u) { where(subject_user: u) if u }

  def self.record!(event_type:, subject:, actor:, request: nil, metadata: {})
    create!(
      event_type: event_type.to_s,
      subject_user: subject,
      actor_user: actor,
      metadata: metadata || {},
      ip: request.respond_to?(:remote_ip) ? request.remote_ip : nil,
      user_agent: request.respond_to?(:user_agent) ? request.user_agent : nil,
      created_at: Time.current
    )
  end
end
