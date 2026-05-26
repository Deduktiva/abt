class Account::SessionsController < ApplicationController
  # Self-service: every action operates on current_user's own sessions.
  allow_without_permission_check

  def index
    @sessions = current_user.sessions.active.order(last_seen_at: :desc)
  end

  def destroy
    session_record = current_user.sessions.find(params[:id])
    is_current = current_user_session&.id == session_record.id
    session_record.terminate!(reason: "user_terminated", actor: current_user, request: request)

    if is_current
      reset_auth_cookie
      Current.user = nil
      Current.session = nil
      redirect_to new_session_path, notice: "Session terminated. You have been signed out."
    else
      redirect_to account_sessions_path, notice: "Session terminated."
    end
  end

  def destroy_all
    current_user.sessions.active.find_each do |s|
      s.terminate!(reason: "user_terminated_all", actor: current_user, request: request)
    end
    reset_auth_cookie
    Current.user = nil
    Current.session = nil
    redirect_to new_session_path, notice: "All sessions terminated. You have been signed out."
  end
end
