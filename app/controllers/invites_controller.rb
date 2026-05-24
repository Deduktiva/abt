class InvitesController < ApplicationController
  allow_unauthenticated_access only: [ :show, :options, :verify ]

  before_action :load_invite

  def show
    if @invite.nil?
      render :invalid, status: :not_found
    end
  end

  def options
    return render_invalid unless @invite

    if @invite.signup?
      build_signup_options
    else
      build_passkey_reset_options
    end
  end

  def verify
    return render_invalid unless @invite

    if @invite.signup?
      complete_signup
    else
      complete_passkey_reset
    end
  end

  private

  def load_invite
    @invite = UserInvite.find_usable(params[:token])
  end

  def render_invalid
    render json: { error: "Invite is invalid or expired" }, status: :unprocessable_content
  end

  def build_signup_options
    username = params[:username].to_s.strip.downcase
    full_name = params[:full_name].to_s.strip
    email = params[:email].to_s.strip.downcase

    errors = signup_form_errors(username, full_name, email)
    if errors.any?
      return render json: { error: errors.first, errors: errors }, status: :unprocessable_content
    end

    webauthn_user_id = WebAuthn.generate_user_id

    options = WebAuthn::Credential.options_for_create(
      user: { id: webauthn_user_id, name: username, display_name: full_name },
      exclude: [],
      authenticator_selection: { resident_key: "required", user_verification: "preferred" }
    )

    webauthn_write(:signup,
      invite_token: params[:token],
      challenge: options.challenge,
      webauthn_user_id: webauthn_user_id,
      username: username,
      full_name: full_name,
      email: email,
      nickname: params[:nickname].to_s.presence || "Initial passkey"
    )

    render json: options.as_json
  end

  def build_passkey_reset_options
    target = @invite.target_user
    return render_invalid unless target

    options = WebAuthn::Credential.options_for_create(
      user: { id: target.webauthn_id, name: target.username, display_name: target.full_name },
      exclude: target.credentials.pluck(:external_id),
      authenticator_selection: { resident_key: "required", user_verification: "preferred" }
    )

    webauthn_write(:passkey_reset,
      invite_token: params[:token],
      challenge: options.challenge,
      target_user_id: target.id,
      nickname: params[:nickname].to_s.presence || "Passkey"
    )

    render json: options.as_json
  end

  def complete_signup
    pending = webauthn_consume(:signup)
    unless invite_token_matches?(pending)
      return render json: { error: "No signup in progress" }, status: :unprocessable_content
    end

    webauthn_credential = verify_webauthn_create(pending["challenge"]) or return

    user = nil
    User.transaction do
      user = User.create!(
        username: pending["username"],
        full_name: pending["full_name"],
        webauthn_id: pending["webauthn_user_id"]
      )

      user.emails.create!(address: pending["email"], confirmed_at: Time.current)

      user.credentials.create!(
        external_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        nickname: pending["nickname"],
        sign_count: webauthn_credential.sign_count
      )

      @invite.consume!(user: user)
    end

    sign_in_user!(user)

    UserAuditEvent.record!(action: "invite_used", user: user, actor: user, request: request,
                            metadata: { purpose: "signup", username: user.username, invite_id: @invite.id })
    UserAuditEvent.record!(action: "signup_completed", user: user, actor: user, request: request,
                            metadata: { username: user.username, email: pending["email"] })
    UserAuditEvent.record!(action: "passkey_added", user: user, actor: user, request: request,
                            metadata: { username: user.username, credential_nickname: pending["nickname"] })
    UserAuditEvent.record!(action: "email_added", user: user, actor: user, request: request,
                            metadata: { username: user.username, address: pending["email"], via: "signup" })
    UserAuditEvent.record!(action: "email_confirmed", user: user, actor: user, request: request,
                            metadata: { username: user.username, address: pending["email"], via: "signup" })

    render json: { redirect_url: account_profile_path }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_content
  end

  def complete_passkey_reset
    pending = webauthn_consume(:passkey_reset)
    unless invite_token_matches?(pending)
      return render json: { error: "No passkey reset in progress" }, status: :unprocessable_content
    end

    target = User.find_by(id: pending["target_user_id"])
    return render_invalid unless target

    webauthn_credential = verify_webauthn_create(pending["challenge"]) or return

    User.transaction do
      target.credentials.create!(
        external_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        nickname: pending["nickname"],
        sign_count: webauthn_credential.sign_count
      )

      @invite.consume!(user: target)

      if target.blocked?
        target.unblock!(actor: target, reason: "passkey_reset_completed", request: request)
      end
    end

    sign_in_user!(target)

    UserAuditEvent.record!(action: "invite_used", user: target, actor: target, request: request,
                            metadata: { purpose: "passkey_reset", username: target.username, invite_id: @invite.id })
    UserAuditEvent.record!(action: "passkey_added", user: target, actor: target, request: request,
                            metadata: { username: target.username, credential_nickname: pending["nickname"], via: "passkey_reset" })

    target.confirmed_emails.each do |email|
      UserMailer.passkey_added_notice(target, target.credentials.last, email.address).deliver_later
    end

    render json: { redirect_url: account_profile_path }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_content
  end

  def invite_token_matches?(pending)
    return false if pending.blank?
    session_token = pending["invite_token"]
    supplied = params[:token]
    return false if session_token.blank? || supplied.blank?
    ActiveSupport::SecurityUtils.secure_compare(session_token, supplied)
  end

  def signup_form_errors(username, full_name, email)
    errors = []
    errors << "Username is required" if username.blank?
    errors << "Username has invalid format" if username.present? && !username.match?(User::USERNAME_FORMAT)
    errors << "Username is taken" if username.present? && User.exists?(username: username)
    errors << "Full name is required" if full_name.blank?
    errors << "Email is required" if email.blank?
    errors << "Email format is invalid" if email.present? && !email.match?(URI::MailTo::EMAIL_REGEXP)
    errors << "Email is taken" if email.present? && UserEmail.exists?(address: email)
    errors
  end
end
