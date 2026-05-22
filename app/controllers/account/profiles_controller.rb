class Account::ProfilesController < ApplicationController
  def show
    @user = current_user
    @emails = @user.emails.order(:created_at)
    @credentials = @user.credentials.order(:created_at)
    @sessions = @user.sessions.active.order(last_seen_at: :desc).limit(10)
    @audit_events = UserAuditEvent.for_user(@user).limit(15)
  end
end
