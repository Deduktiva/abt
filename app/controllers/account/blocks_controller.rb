class Account::BlocksController < ApplicationController
  # Self-service: user blocking their own account.
  allow_without_permission_check

  def create
    current_user.block!(
      reason: "user self-requested",
      actor: current_user,
      request: request
    )
    reset_auth_cookie
    Current.user = nil
    Current.session = nil
    redirect_to new_session_path, notice: "Your account has been blocked at your request."
  end
end
