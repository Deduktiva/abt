class Account::ProfilesController < ApplicationController
  # Self-service: every action operates on current_user.
  allow_without_permission_check

  def show
    @user = current_user
    @emails = @user.emails.order(:created_at)
    @credentials = @user.credentials.order(:created_at)
    @sessions = @user.sessions.active.order(last_seen_at: :desc).limit(10)
    @audit_events = UserAuditEvent.for_user(@user).limit(15)
    @user_groups = @user.groups.ordered
    @user_teams = @user.teams.ordered
  end
end
