class SessionsController < ApplicationController
  allow_unauthenticated_access only: [:new, :options, :verify]

  def new
  end

  def options
    user = User.active.find_by(username: params[:username].to_s.strip.downcase)
    credentials = user ? user.credentials : []

    options = WebAuthn::Credential.options_for_get(
      allow: credentials.map(&:external_id),
      user_verification: 'preferred'
    )

    session[:webauthn_login] = {
      challenge: options.challenge,
      username: user&.username,
      user_id: user&.id
    }

    render json: options.as_json
  end

  def verify
    login_session = session[:webauthn_login]
    if login_session.blank? || login_session['user_id'].blank?
      return render json: { error: 'No login in progress' }, status: :unprocessable_content
    end

    user = User.active.find_by(id: login_session['user_id'])
    return render_login_error('Authentication failed') unless user

    webauthn_credential = WebAuthn::Credential.from_get(params[:credential].to_unsafe_h)
    stored = user.credentials.find_by(external_id: webauthn_credential.id)
    unless stored
      UserAuditEvent.record!(
        action: 'login_failed', user: user, request: request,
        metadata: { reason: 'unknown_credential', username: user.username }
      )
      return render_login_error('Authentication failed')
    end

    begin
      webauthn_credential.verify(
        login_session['challenge'],
        public_key: stored.public_key,
        sign_count: stored.sign_count,
        user_verification: false
      )
    rescue WebAuthn::Error => e
      UserAuditEvent.record!(
        action: 'login_failed', user: user, request: request,
        metadata: { reason: e.class.name, username: user.username }
      )
      return render_login_error('Authentication failed')
    end

    stored.touch_used!(webauthn_credential.sign_count)
    session.delete(:webauthn_login)
    new_session = sign_in_user!(user)
    UserAuditEvent.record!(
      action: 'login_success', user: user, actor: user, request: request,
      metadata: { username: user.username, credential_nickname: stored.nickname, session_id: new_session.id }
    )

    render json: { redirect_url: root_path }
  end

  def destroy
    if current_user_session
      current_user_session.terminate!(
        reason: 'logout',
        actor: current_user,
        request: request
      )
      UserAuditEvent.record!(
        action: 'logout', user: current_user, actor: current_user,
        request: request, metadata: { username: current_user.username }
      )
    end
    reset_session_cookie
    Current.user = nil
    Current.session = nil
    redirect_to new_session_path, notice: 'Signed out.'
  end

  private

  def render_login_error(message)
    session.delete(:webauthn_login)
    render json: { error: message }, status: :unauthorized
  end
end
