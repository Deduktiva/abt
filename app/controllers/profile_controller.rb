class ProfileController < ApplicationController
  def show
    @user = current_user
    @identities = @user.identities.order(:provider)
    @passkeys = @user.webauthn_credentials.ordered
    @recent_events = AuditEvent.for_subject(@user).recent.limit(20)
  end

  def block
    user = current_user
    user.block!(by: user, reason: "user self-requested", audit_request: request, event_type: "self_block")
    cookies.delete(ApplicationController::SESSION_COOKIE)
    redirect_to login_path, notice: "Your account has been disabled."
  end
end
