class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  AUTH_COOKIE = :abt_auth

  before_action :authenticate

  helper_method :current_user, :current_user_session

  class << self
    def allow_unauthenticated_access(**options)
      skip_before_action :authenticate, **options
    end
  end

  def current_user
    Current.user
  end

  def current_user_session
    Current.session
  end

  private

  def authenticate
    plaintext = read_auth_token
    session_record = plaintext.present? ? UserSession.authenticate(plaintext) : nil

    if session_record.nil?
      reset_auth_cookie
      redirect_to_login and return
    end

    user = session_record.user
    if user.blocked?
      session_record.terminate!(reason: "blocked_user", actor: nil) unless session_record.terminated_at
      reset_auth_cookie
      redirect_to_login(alert: "Your account has been blocked.") and return
    end

    session_record.touch_seen!(request)

    Current.user = user
    Current.session = session_record
    Current.request_ip = request.remote_ip
    Current.user_agent = request.user_agent
  end

  def redirect_to_login(alert: "You must sign in to continue.")
    respond_to do |format|
      format.html { redirect_to new_session_path, alert: alert }
      format.json { render json: { error: alert }, status: :unauthorized }
      format.any  { head :unauthorized }
    end
  end

  def reset_auth_cookie
    cookies.delete(AUTH_COOKIE)
  end

  def read_auth_token
    value = cookies.signed[AUTH_COOKIE]
    return value if value.present?
    # In test env, integration tests cannot easily set signed cookies through
    # rack-test's CookieJar; allow the raw cookie as a fallback there.
    return cookies[AUTH_COOKIE] if Rails.env.test?
    nil
  end

  def webauthn_write(flow, **payload)
    WebauthnPendingStore.write(session: session, flow: flow, **payload)
  end

  def webauthn_consume(flow)
    WebauthnPendingStore.consume(session: session, flow: flow)
  end

  def sign_in_user!(user)
    session_record, plaintext = UserSession.create_for!(user: user, request: request)
    cookies.signed.permanent[AUTH_COOKIE] = {
      value: plaintext,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
    session_record
  end
end
