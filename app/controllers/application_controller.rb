class ApplicationController < ActionController::Base
  SESSION_COOKIE = :abt_session_token

  protect_from_forgery with: :exception

  before_action :require_login

  helper_method :current_user, :current_session, :logged_in?

  private

  def require_login
    return if current_user
    redirect_to login_path, alert: "Please sign in."
  end

  def current_session
    return @current_session if defined?(@current_session)

    raw = cookies.encrypted[SESSION_COOKIE]
    record = UserSession.find_active_by_token(raw)

    if record && record.user.blocked?
      record.terminate!(reason: "blocked")
      cookies.delete(SESSION_COOKIE)
      @current_session = nil
      return @current_session
    end

    if record
      record.update_columns(last_seen_at: Time.current)
      record.user.update_columns(last_seen_at: Time.current) if record.user
    end

    @current_session = record
  end

  def current_user
    current_session&.user
  end

  def logged_in?
    current_user.present?
  end

  def start_user_session!(user)
    record, raw = UserSession.start!(user: user, request: request)
    cookies.encrypted[SESSION_COOKIE] = {
      value: raw,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?,
      expires: 30.days.from_now
    }
    @current_session = record
    record
  end

  def terminate_current_session!(reason: "logout")
    s = current_session
    s&.terminate!(reason: reason)
    cookies.delete(SESSION_COOKIE)
    @current_session = nil
  end
end
