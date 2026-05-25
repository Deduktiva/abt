module TeamOwned
  extend ActiveSupport::Concern

  included do
    belongs_to :team

    # Unconditional once team_id is being written. The check reads
    # Current.user, which ApplicationController#authenticate sets on every
    # authenticated request. A new controller that handles a TeamOwned
    # record therefore can't "forget" to authorize the assignment.
    validate :validate_team_assignment, if: :will_save_change_to_team_id?
  end

  class_methods do
    # Restrict a relation to records the user can see. Bypass-scoping users
    # see everything; everyone else sees records in teams they're a member of.
    def visible_to(user)
      return none if user.nil?
      return all if user.bypass_team_scoping?
      where(team_id: user.team_ids)
    end
  end

  private

  def validate_team_assignment
    # Current.user is nil in system contexts (seeds, console, background
    # jobs); the validation skips and those callers can seed freely. Inside
    # a request it's always set by the authenticate before_action.
    user = Current.user
    return if user.nil?
    return if user.bypass_team_scoping?
    return if team_id && user.team_ids.include?(team_id)
    errors.add(:team_id, "must be a team you are a member of")
  end
end
