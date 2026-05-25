class Account::AuditEventsController < ApplicationController
  # Self-service: scoped to current_user.
  allow_without_permission_check

  def index
    @audit_events = UserAuditEvent.for_user(current_user).limit(200)
  end
end
