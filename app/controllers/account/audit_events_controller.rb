class Account::AuditEventsController < ApplicationController
  def index
    @audit_events = UserAuditEvent.for_user(current_user).limit(200)
  end
end
