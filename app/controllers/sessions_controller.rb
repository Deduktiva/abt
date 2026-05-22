class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :callback, :failure, :passkey_options, :passkey_login]

  def new
    redirect_to root_path and return if logged_in?
  end

  def destroy
    if current_session
      AuditEvent.record!(event_type: "logout", subject: current_user, actor: current_user, request: request)
      terminate_current_session!(reason: "logout")
    end
    redirect_to login_path, notice: "Signed out."
  end

  def callback
    auth = request.env["omniauth.auth"]
    if auth.blank?
      redirect_to login_path, alert: "Authentication failed." and return
    end

    identity = UserIdentity.find_by(provider: auth.provider.to_s, uid: auth.uid.to_s)
    pending_token = session.delete(:pending_invite_token)

    if identity
      complete_login(identity, auth)
    elsif pending_token && (invite = UserInvite.find_by(token: pending_token))&.consumable?
      session[:pending_auth] = {
        "provider" => auth.provider.to_s,
        "uid" => auth.uid.to_s,
        "nickname" => auth.info&.nickname,
        "name" => auth.info&.name,
        "email" => auth.info&.email,
        "raw_info" => (auth.info&.to_h || {})
      }
      session[:pending_invite_token] = invite.token
      redirect_to invite_path(invite.token)
    else
      AuditEvent.record!(event_type: "login_failed", subject: nil, actor: nil, request: request,
                         metadata: { provider: auth.provider.to_s, uid: auth.uid.to_s, reason: "no_identity_no_invite" })
      redirect_to login_path, alert: "No account is linked to that GitHub identity. You need an invite."
    end
  end

  def failure
    AuditEvent.record!(event_type: "login_failed", subject: nil, actor: nil, request: request,
                       metadata: { message: params[:message], strategy: params[:strategy] })
    @message = params[:message]
    render :failure, status: :unauthorized
  end

  # Step 1 of passkey sign-in: return a challenge for the client. The
  # challenge is stashed in the session and consumed by #passkey_login.
  def passkey_options
    options = WebAuthn::Credential.options_for_get(user_verification: "required")
    session[:passkey_login_challenge] = options.challenge
    render json: options
  end

  # Step 2: verify the assertion against the stored challenge and credential.
  def passkey_login
    challenge = session.delete(:passkey_login_challenge)
    if challenge.blank?
      render json: { error: "missing challenge — restart sign-in" }, status: :unprocessable_content and return
    end

    credential = WebAuthn::Credential.from_get(params.require(:credential).to_unsafe_h)
    record = WebauthnCredential.find_by(external_id: credential.id)
    unless record
      AuditEvent.record!(event_type: "login_failed", subject: nil, actor: nil, request: request,
                         metadata: { method: "passkey", reason: "unknown_credential" })
      render json: { error: "unknown credential" }, status: :unauthorized and return
    end

    if record.user.blocked?
      AuditEvent.record!(event_type: "login_failed", subject: record.user, actor: nil, request: request,
                         metadata: { method: "passkey", reason: "blocked" })
      render json: { error: "account blocked" }, status: :unauthorized and return
    end

    credential.verify(
      challenge,
      public_key: record.public_key,
      sign_count: record.sign_count,
      user_verification: true
    )

    record.record_use!(new_sign_count: credential.sign_count)

    start_user_session!(record.user)
    AuditEvent.record!(event_type: "login", subject: record.user, actor: record.user, request: request,
                       metadata: { method: "passkey", credential_id: record.id })
    render json: { ok: true, redirect_to: root_path }
  rescue WebAuthn::Error => e
    AuditEvent.record!(event_type: "login_failed", subject: record&.user, actor: nil, request: request,
                       metadata: { method: "passkey", reason: e.class.name, message: e.message })
    render json: { error: "verification failed" }, status: :unauthorized
  end

  private

  def complete_login(identity, auth)
    user = identity.user
    if user.blocked?
      AuditEvent.record!(event_type: "login_failed", subject: user, actor: nil, request: request,
                         metadata: { provider: auth.provider.to_s, reason: "blocked" })
      redirect_to login_path, alert: "Your account is blocked." and return
    end

    # Refresh stored identity info
    identity.nickname = auth.info&.nickname
    identity.email = auth.info&.email
    identity.raw_info = auth.info&.to_h || {}
    identity.save! if identity.changed?

    start_user_session!(user)
    AuditEvent.record!(event_type: "login", subject: user, actor: user, request: request,
                       metadata: { method: "oauth", provider: auth.provider.to_s })
    redirect_to root_path, notice: "Signed in."
  end
end
