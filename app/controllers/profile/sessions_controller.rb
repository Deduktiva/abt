class Profile::SessionsController < ApplicationController
  def index
    @sessions = current_user.sessions.active.order(last_seen_at: :desc)
    @current_session_id = current_session&.id
  end

  def destroy
    session_record = current_user.sessions.find(params[:id])
    is_current = session_record.id == current_session&.id

    session_record.terminate!(reason: "by-user")
    AuditEvent.record!(event_type: "session_terminated", subject: current_user, actor: current_user, request: request,
                       metadata: { session_id: session_record.id, was_current: is_current })

    if is_current
      cookies.delete(ApplicationController::SESSION_COOKIE)
      redirect_to login_path, notice: "Session terminated."
    else
      redirect_to profile_sessions_path, notice: "Session terminated."
    end
  end
end
