class AuditEventsController < ApplicationController
  def index
    @events = AuditEvent.recent.limit(100)
    @events = @events.where(subject_user_id: params[:user_id]) if params[:user_id].present?
    @events = @events.by_type(params[:event_type]) if params[:event_type].present?
    @event_types = AuditEvent::EVENT_TYPES
    @users = User.order(:username)
  end
end
