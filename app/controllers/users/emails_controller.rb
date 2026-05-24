class Users::EmailsController < ApplicationController
  before_action :load_user

  def create
    address = params.dig(:user_email, :address).to_s.strip.downcase
    email = @user.emails.build(address: address, confirmed_at: Time.current)

    if email.save
      UserAuditEvent.record!(action: "email_added", user: @user, actor: current_user,
                              request: request,
                              metadata: { username: @user.username, address: address, via: "admin" })
      UserAuditEvent.record!(action: "email_confirmed", user: @user, actor: current_user,
                              request: request,
                              metadata: { username: @user.username, address: address, via: "admin" })

      @user.confirmed_emails.where.not(id: email.id).find_each do |existing|
        UserMailer.email_added_notice(@user, address, existing.address).deliver_later
      end
      UserMailer.email_added_notice(@user, address, address).deliver_later

      redirect_to user_path(@user), notice: "Email #{address} added."
    else
      redirect_to user_path(@user), alert: email.errors.full_messages.join(", ")
    end
  end

  def update
    email = @user.emails.find(params[:id])
    old_address = email.address
    new_address = params.dig(:user_email, :address).to_s.strip.downcase

    if email.update(address: new_address, confirmed_at: Time.current, confirmation_token_digest: nil, confirmation_expires_at: nil)
      UserAuditEvent.record!(action: "email_removed", user: @user, actor: current_user,
                              request: request,
                              metadata: { username: @user.username, address: old_address, via: "admin_replace" })
      UserAuditEvent.record!(action: "email_added", user: @user, actor: current_user,
                              request: request,
                              metadata: { username: @user.username, address: new_address, via: "admin_replace" })

      @user.confirmed_emails.find_each do |existing|
        UserMailer.email_removed_notice(@user, old_address, existing.address).deliver_later
      end
      redirect_to user_path(@user), notice: "Email replaced: #{old_address} → #{new_address}."
    else
      redirect_to user_path(@user), alert: email.errors.full_messages.join(", ")
    end
  end

  def destroy
    email = @user.emails.find(params[:id])
    if email.confirmed? && @user.confirmed_emails.count <= 1
      redirect_to user_path(@user), alert: "Cannot remove the last confirmed email." and return
    end

    address = email.address
    email.destroy!

    UserAuditEvent.record!(action: "email_removed", user: @user, actor: current_user,
                            request: request,
                            metadata: { username: @user.username, address: address, via: "admin" })

    @user.confirmed_emails.find_each do |existing|
      UserMailer.email_removed_notice(@user, address, existing.address).deliver_later
    end

    redirect_to user_path(@user), notice: "Email #{address} removed."
  end

  private

  def load_user
    @user = User.find(params[:user_id])
  end
end
