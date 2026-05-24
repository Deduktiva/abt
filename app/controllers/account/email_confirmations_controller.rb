class Account::EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access only: [ :show ]

  def show
    email = UserEmail.find_by_confirmation_token(params[:token])
    if email.nil?
      flash[:alert] = 'Email confirmation link is invalid or expired.'
      redirect_to(current_user ? account_emails_path : new_session_path) and return
    end

    email.confirm!

    UserAuditEvent.record!(action: 'email_confirmed', user: email.user, actor: email.user,
                            request: request,
                            metadata: { username: email.user.username, address: email.address })

    flash[:notice] = "Email #{email.address} confirmed."
    redirect_to(current_user ? account_emails_path : new_session_path)
  end
end
