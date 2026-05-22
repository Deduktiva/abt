class Profile::PasskeysController < ApplicationController
  # Registration is a two-step XHR dance: first GET-like POST to fetch
  # challenge options, then POST the attestation. The Stimulus controller
  # sends the X-CSRF-Token header so the default CSRF check passes.

  def index
    @passkeys = current_user.webauthn_credentials.ordered
  end

  def registration_options
    options = WebAuthn::Credential.options_for_create(
      user: {
        id: current_user.webauthn_id,
        name: current_user.username,
        display_name: current_user.full_name
      },
      exclude: current_user.webauthn_credentials.pluck(:external_id),
      authenticator_selection: { user_verification: "required", resident_key: "preferred" }
    )
    session[:passkey_register_challenge] = options.challenge
    render json: options
  end

  def create
    challenge = session.delete(:passkey_register_challenge)
    if challenge.blank?
      render json: { error: "missing challenge — restart registration" }, status: :unprocessable_content and return
    end

    credential = WebAuthn::Credential.from_create(params.require(:credential).to_unsafe_h)
    credential.verify(challenge, user_verification: true)

    transports = credential.response.transports if credential.response.respond_to?(:transports)

    record = current_user.webauthn_credentials.create!(
      external_id:  credential.id,
      public_key:   credential.public_key,
      sign_count:   credential.sign_count,
      nickname:     params[:nickname].to_s.strip.presence || default_nickname,
      transports:   Array(transports),
      last_used_at: Time.current
    )

    AuditEvent.record!(event_type: "passkey_added", subject: current_user, actor: current_user,
                       request: request, metadata: { credential_id: record.id, nickname: record.nickname })

    render json: { ok: true, id: record.id, nickname: record.nickname, redirect_to: profile_passkeys_path }
  rescue WebAuthn::Error => e
    render json: { error: "verification failed: #{e.message}" }, status: :unprocessable_content
  end

  def destroy
    cred = current_user.webauthn_credentials.find(params[:id])
    if current_user.sign_in_methods_count <= 1
      redirect_to profile_passkeys_path, alert: "Cannot remove your last sign-in method." and return
    end
    cred.destroy!
    AuditEvent.record!(event_type: "passkey_removed", subject: current_user, actor: current_user,
                       request: request, metadata: { credential_id: cred.id, nickname: cred.nickname })
    redirect_to profile_passkeys_path, notice: "Passkey removed."
  end

  private

  def default_nickname
    ua = request.user_agent.to_s
    case ua
    when /iPhone|iPad/  then "iOS (#{Time.current.strftime('%Y-%m-%d')})"
    when /Android/      then "Android (#{Time.current.strftime('%Y-%m-%d')})"
    when /Mac OS X/     then "Mac (#{Time.current.strftime('%Y-%m-%d')})"
    when /Windows/      then "Windows (#{Time.current.strftime('%Y-%m-%d')})"
    else                     "Passkey (#{Time.current.strftime('%Y-%m-%d')})"
    end
  end
end
