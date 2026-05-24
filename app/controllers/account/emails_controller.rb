class Account::EmailsController < ApplicationController
  def index
    @emails = current_user.emails.order(:created_at)
  end

  def create
    address = params.dig(:user_email, :address).to_s.strip.downcase

    UserEmail.transaction do
      email = current_user.emails.create!(address: address)
      plaintext = email.generate_confirmation_token!

      UserAuditEvent.record!(action: 'email_added', user: current_user, actor: current_user,
                              request: request,
                              metadata: { username: current_user.username, address: address })

      confirmation_url = AbsoluteUrl.account_email_confirmation(plaintext)
      UserMailer.email_confirmation(email, confirmation_url).deliver_later

      current_user.confirmed_emails.where.not(id: email.id).find_each do |existing|
        UserMailer.email_added_notice(current_user, address, existing.address).deliver_later
      end
    end

    redirect_to account_emails_path, notice: 'Confirmation email sent. Click the link to activate the address.'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to account_emails_path, alert: e.record.errors.full_messages.join(', ')
  end

  def destroy
    email = current_user.emails.find(params[:id])

    if email.confirmed? && current_user.confirmed_emails.count <= 1
      redirect_to account_emails_path, alert: 'Cannot remove the last confirmed email. Add another one first.' and return
    end

    address = email.address
    email.destroy!

    UserAuditEvent.record!(action: 'email_removed', user: current_user, actor: current_user,
                            request: request,
                            metadata: { username: current_user.username, address: address })

    current_user.confirmed_emails.find_each do |existing|
      UserMailer.email_removed_notice(current_user, address, existing.address).deliver_later
    end

    redirect_to account_emails_path, notice: "Email #{address} removed."
  end
end
