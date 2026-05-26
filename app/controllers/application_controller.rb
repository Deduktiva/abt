class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  AUTH_COOKIE = :abt_auth

  before_action :authenticate
  after_action  :verify_permission_check_performed

  helper_method :current_user, :current_user_session, :available_teams

  class PermissionDenied < StandardError; end
  class MissingPermissionCheck < StandardError; end
  rescue_from PermissionDenied, with: :deny_permission
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_authenticity_token

  class << self
    def allow_unauthenticated_access(**options)
      skip_before_action :authenticate, **options
      skip_after_action :verify_permission_check_performed, **options
    end

    # Mark actions as intentionally not requiring a permission check.
    # Use for self-service surfaces (account/*) and the dashboard where the
    # data is already scoped to the current user.
    def allow_without_permission_check(**options)
      skip_after_action :verify_permission_check_performed, **options
    end
  end

  def current_user
    Current.user
  end

  def current_user_session
    Current.session
  end

  def require_permission!(key)
    @_permission_check_performed = true
    raise PermissionDenied, key unless current_user&.permission?(key)
  end

  def deny_permission(exception)
    Rails.logger.info "Permission denied for user #{current_user&.username.inspect} key=#{exception.message}"
    respond_to do |format|
      format.html { redirect_to root_path, alert: "You don't have permission to access that page." }
      format.json { render json: { error: "permission_denied" }, status: :forbidden }
      format.turbo_stream { redirect_to root_path, alert: "You don't have permission to access that page." }
      format.any  { head :forbidden }
    end
  end

  # CSRF token check failed — usually a stale tab whose session rotated
  # (sign-out in another tab, server-side session expiry, cookies cleared).
  # Surface a clear, recovery-oriented message instead of Rails' default
  # 422.html / dev exception page. The handler must not auto-reload the
  # page: that would silently discard whatever the user just typed.
  def handle_invalid_authenticity_token(exception)
    message = "Your security token has expired. Reload this page to try again."
    Rails.logger.warn "[csrf] InvalidAuthenticityToken on #{request.method} #{request.path} ua=#{request.user_agent.inspect}"
    respond_to do |format|
      format.json { render json: { error: message }, status: :unprocessable_content }
      format.html { render "errors/csrf_failure", layout: "application", status: :unprocessable_content, locals: { message: message } }
      format.any  { head :unprocessable_content }
    end
  end

  # Fails the response if the action never called require_permission!. Any
  # controller action that handles authenticated user data must either gate
  # on a permission or explicitly opt out via allow_without_permission_check.
  # This catches "forgot to add a before_action" bugs at request time rather
  # than at code review.
  def verify_permission_check_performed
    return if @_permission_check_performed
    msg = "No permission check performed for #{self.class.name}##{action_name}. " \
          "Add `before_action -> { require_permission!('...') }` or " \
          "`allow_without_permission_check only: [:#{action_name}]` if intentional."
    Rails.logger.error "[authorization] #{msg}"
    raise MissingPermissionCheck, msg
  end

  # Teams the current user may assign records to. Bypass-scoping users see
  # every team; everyone else sees only the teams they're a member of.
  # Used by the customer and project forms.
  def available_teams
    @available_teams ||= if current_user&.bypass_team_scoping?
                           Team.ordered.to_a
    else
                           current_user ? current_user.teams.ordered.to_a : []
    end
  end

  # Record a privilege-change audit event with the current actor and request.
  # Used by GroupsController/TeamsController/UsersController to log group
  # CRUD, team CRUD, and membership changes.
  def audit_privilege_change!(action, user: nil, metadata: {})
    UserAuditEvent.record!(
      action: action,
      user: user,
      actor: current_user,
      request: request,
      metadata: metadata
    )
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
  end

  def redirect_to_login(alert: "You must sign in to continue.")
    respond_to do |format|
      format.html { redirect_to new_session_path, alert: alert }
      format.json { render json: { error: alert }, status: :unauthorized }
      format.any  { head :unauthorized }
    end
  end

  # Tears down all browser-side auth state: the signed auth cookie AND the
  # Rails framework session (`_abt_session`). Rotating the framework session
  # ensures WebAuthn pending-state nonces — and any other session-stored
  # keys — cannot leak across users sharing a browser. Every caller wants
  # both; do not split.
  def reset_auth_cookie
    cookies.delete(AUTH_COOKIE)
    reset_session
  end

  # Full sign-out for action endpoints that end with the user signed out:
  # tears down the auth cookie + framework session, clears Current so any
  # after_action / logging callback sees the user as anonymous, and
  # redirects to the sign-in page with a notice. Callers are responsible
  # for terminating UserSession records before invoking.
  def sign_out_and_redirect(notice:)
    reset_auth_cookie
    Current.user = nil
    Current.session = nil
    redirect_to new_session_path, notice: notice
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

  # Verifies a WebAuthn create-style assertion against the given challenge.
  # Returns the credential on success; on a missing/malformed credential
  # payload or WebAuthn::Error, renders a 422 JSON error and returns nil —
  # callers should `return` on nil.
  def verify_webauthn_create(challenge)
    payload = params[:credential]
    unless payload.is_a?(ActionController::Parameters)
      render json: { error: "Verification failed: missing credential payload" }, status: :unprocessable_content
      return nil
    end
    credential = WebAuthn::Credential.from_create(payload.to_unsafe_h)
    credential.verify(challenge)
    credential
  rescue WebAuthn::Error => e
    render json: { error: "Verification failed: #{e.message}" }, status: :unprocessable_content
    nil
  end

  # Rotates the framework session on every successful authentication.
  # Defends against session fixation and clears any pending-state keys
  # left by prior WebAuthn flows. Callers MUST finish reading any
  # session-tied state (e.g. webauthn_consume) BEFORE calling this.
  def sign_in_user!(user)
    reset_session
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
