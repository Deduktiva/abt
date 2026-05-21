class UsersController < ApplicationController
  def index
    @users = User.order(:username)
  end

  def show
    @user = User.find_by!(username: params[:id])
    @identities = @user.identities.order(:provider)
    @active_sessions = @user.sessions.active.order(last_seen_at: :desc)
    @recent_events = AuditEvent.for_subject(@user).recent.limit(20)
  end

  def block
    @user = User.find_by!(username: params[:id])
    if @user == current_user
      redirect_to user_path(@user), alert: "Use the profile page to block your own account." and return
    end
    reason = params[:reason].presence || "blocked by #{current_user.username}"
    @user.block!(by: current_user, reason: reason, audit_request: request)
    redirect_to user_path(@user), notice: "User blocked."
  end

  def unblock
    @user = User.find_by!(username: params[:id])
    @user.unblock!(by: current_user, audit_request: request)
    redirect_to user_path(@user), notice: "User unblocked."
  end
end
