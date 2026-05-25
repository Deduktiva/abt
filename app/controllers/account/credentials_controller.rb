class Account::CredentialsController < ApplicationController
  # Self-service: every action operates on current_user's own credentials.
  allow_without_permission_check

  def index
    @credentials = current_user.credentials.order(:created_at)
  end

  def new
  end

  def options
    nickname = params[:nickname].to_s.strip
    if nickname.blank?
      return render json: { error: "Nickname is required" }, status: :unprocessable_content
    end

    options = WebAuthn::Credential.options_for_create(
      user: { id: current_user.webauthn_id, name: current_user.username, display_name: current_user.full_name },
      exclude: current_user.credentials.pluck(:external_id),
      authenticator_selection: { resident_key: "required", user_verification: "preferred" }
    )

    webauthn_write(:credential_add, challenge: options.challenge, nickname: nickname)

    render json: options.as_json
  end

  def verify
    pending = webauthn_consume(:credential_add)
    if pending.blank?
      return render json: { error: "No registration in progress" }, status: :unprocessable_content
    end

    webauthn_credential = verify_webauthn_create(pending["challenge"]) or return

    credential = current_user.credentials.create!(
      external_id: webauthn_credential.id,
      public_key: webauthn_credential.public_key,
      nickname: pending["nickname"],
      sign_count: webauthn_credential.sign_count
    )

    UserAuditEvent.record!(action: "passkey_added", user: current_user, actor: current_user,
                            request: request,
                            metadata: { username: current_user.username, credential_nickname: credential.nickname })

    current_user.confirmed_emails.each do |email|
      UserMailer.passkey_added_notice(current_user, credential, email.address).deliver_later
    end

    render json: { redirect_url: account_credentials_path }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_content
  end

  def destroy
    credential = current_user.credentials.find(params[:id])
    if current_user.credentials.count <= 1
      redirect_to account_credentials_path, alert: "Cannot remove the last passkey. Add another one first." and return
    end

    nickname = credential.nickname
    credential.destroy!

    UserAuditEvent.record!(action: "passkey_removed", user: current_user, actor: current_user,
                            request: request,
                            metadata: { username: current_user.username, credential_nickname: nickname })

    current_user.confirmed_emails.each do |email|
      UserMailer.passkey_removed_notice(current_user, nickname, email.address).deliver_later
    end

    redirect_to account_credentials_path, notice: "Passkey \"#{nickname}\" removed."
  end
end
