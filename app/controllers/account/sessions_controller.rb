class Account::SessionsController < ApplicationController
  def index
    @sessions = current_user.sessions.active.order(last_seen_at: :desc)
  end

  def destroy
    session_record = current_user.sessions.find(params[:id])
    is_current = current_user_session&.id == session_record.id
    session_record.terminate!(reason: "user_terminated", actor: current_user, request: request)

    if is_current
      reset_session_cookie
      Current.user = nil
      Current.session = nil
      redirect_to new_session_path, notice: "Session terminated. You have been signed out."
    else
      redirect_to account_sessions_path, notice: "Session terminated."
    end
  end
end
