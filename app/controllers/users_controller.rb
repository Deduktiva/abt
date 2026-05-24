class UsersController < ApplicationController
  before_action :load_user, only: [:show, :block, :unblock, :reset_passkeys, :audit]

  def index
    @users = User.order(:username)
  end

  def show
    @emails = @user.emails.order(:created_at)
    @credentials = @user.credentials.order(:created_at)
    @sessions = @user.sessions.active.order(last_seen_at: :desc).limit(20)
  end

  def block
    if @user.id == current_user.id
      redirect_to user_path(@user), alert: 'Use the self-block button on your account page to block yourself.' and return
    end
    if @user.blocked?
      redirect_to user_path(@user), alert: 'User is already blocked.' and return
    end

    reason = params[:reason].to_s.strip
    if reason.blank?
      redirect_to user_path(@user), alert: 'Reason is required.' and return
    end

    @user.block!(reason: reason, actor: current_user, request: request)
    redirect_to user_path(@user), notice: "User #{@user.username} blocked."
  end

  def unblock
    unless @user.blocked?
      redirect_to user_path(@user), alert: 'User is not blocked.' and return
    end

    @user.unblock!(actor: current_user, reason: 'admin_unblock', request: request)
    redirect_to user_path(@user), notice: "User #{@user.username} unblocked."
  end

  def reset_passkeys
    unless @user.blocked?
      redirect_to user_path(@user), alert: 'User must be blocked before resetting passkeys.' and return
    end

    _invite, plaintext = @user.reset_passkeys!(actor: current_user, request: request)
    invite_url = AbsoluteUrl.invite(plaintext)

    UserAuditEvent.record!(action: 'invite_created', user: @user, actor: current_user,
                            request: request,
                            metadata: { purpose: 'passkey_reset', username: @user.username })

    @user.emails.find_each do |email|
      UserMailer.passkey_reset_invite(@user, invite_url, email.address).deliver_later
    end

    redirect_to user_path(@user), notice: "Passkeys reset; invite sent to #{@user.emails.count} email address(es)."
  end

  def audit
    @audit_events = UserAuditEvent.for_user(@user).limit(200)
  end

  private

  def load_user
    @user = User.find(params[:id])
  end
end
