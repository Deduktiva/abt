class UserAuditEvent < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :actor, class_name: "User", foreign_key: :actor_user_id, optional: true

  serialize :metadata, coder: JSON

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def self.record!(action:, user: nil, actor: nil, request: nil, metadata: {})
    create!(
      action: action.to_s,
      user: user,
      actor: actor,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent.to_s.first(500),
      metadata: metadata.is_a?(Hash) ? metadata.compact : metadata,
      created_at: Time.current
    )
  end

  def self.for_user(user)
    where("user_id = :id OR actor_user_id = :id", id: user.id).recent
  end
end
