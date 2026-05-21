class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :callback, :failure]

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
                       metadata: { provider: auth.provider.to_s })
    redirect_to root_path, notice: "Signed in."
  end
end
