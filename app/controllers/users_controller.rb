class UsersController < ApplicationController
  before_action -> { require_permission!("users.view") }, only: [ :index, :show, :audit ]
  before_action -> { require_permission!("users.block") }, only: [ :block, :unblock ]
  before_action -> { require_permission!("users.reset_passkeys") }, only: [ :reset_passkeys ]
  before_action -> { require_permission!("groups.manage") }, only: [ :update_groups ]
  before_action -> { require_permission!("teams.manage") }, only: [ :update_teams ]

  before_action :load_user, only: [ :show, :block, :unblock, :reset_passkeys, :audit, :update_groups, :update_teams ]

  def index
    @users = User.order(:username)
  end

  def show
    @emails = @user.emails.order(:created_at)
    @credentials = @user.credentials.order(:created_at)
    @sessions = @user.sessions.active.order(last_seen_at: :desc).limit(20)
    @user_groups = @user.groups.ordered
    @user_teams = @user.teams.ordered
  end

  def block
    if @user.id == current_user.id
      redirect_to user_path(@user), alert: "Use the self-block button on your account page to block yourself." and return
    end
    if @user.blocked?
      redirect_to user_path(@user), alert: "User is already blocked." and return
    end

    reason = params[:reason].to_s.strip
    if reason.blank?
      redirect_to user_path(@user), alert: "Reason is required." and return
    end

    @user.block!(reason: reason, actor: current_user, request: request)
    redirect_to user_path(@user), notice: "User #{@user.username} blocked."
  end

  def unblock
    unless @user.blocked?
      redirect_to user_path(@user), alert: "User is not blocked." and return
    end

    @user.unblock!(actor: current_user, reason: "admin_unblock", request: request)
    redirect_to user_path(@user), notice: "User #{@user.username} unblocked."
  end

  def reset_passkeys
    unless @user.blocked?
      redirect_to user_path(@user), alert: "User must be blocked before resetting passkeys." and return
    end

    _invite, plaintext = @user.reset_passkeys!(actor: current_user, request: request)
    invite_url = AbsoluteUrl.invite(plaintext)

    UserAuditEvent.record!(action: "invite_created", user: @user, actor: current_user,
                            request: request,
                            metadata: { purpose: "passkey_reset", username: @user.username })

    @user.confirmed_emails.find_each do |email|
      UserMailer.passkey_reset_invite(@user, invite_url, email.address).deliver_later
    end

    redirect_to user_path(@user), notice: "Passkeys reset; invite sent to #{@user.confirmed_emails.count} email address(es)."
  end

  def audit
    @audit_events = UserAuditEvent.for_user(@user).limit(200)
  end

  def update_groups
    new_ids = Array(params[:group_ids]).reject(&:blank?).map(&:to_i)
    new_groups = Group.where(id: new_ids).to_a

    admin_group = Group.admin
    if admin_group && @user.groups.include?(admin_group) && !new_groups.include?(admin_group)
      if admin_group.users.where.not(id: @user.id).none?
        redirect_to user_path(@user), alert: "Cannot remove the last member of the Admin group." and return
      end
    end

    # Only admins can change Admin-group membership in either direction.
    # `groups.manage` alone is insufficient: the add direction is admin
    # self-promotion (bypass_team_scoping + admin-only credential primitives);
    # the remove direction lets a non-admin demote any admin (down to the
    # last-admin floor enforced above), which is unauthorized privilege
    # modification + an admin-lockout primitive.
    if admin_group && !current_user.groups.include?(admin_group)
      adding_admin   = new_groups.include?(admin_group) && !@user.groups.include?(admin_group)
      removing_admin = @user.groups.include?(admin_group) && !new_groups.include?(admin_group)
      if adding_admin || removing_admin
        redirect_to user_path(@user), alert: "Only members of the Admin group can change Admin membership." and return
      end
    end

    previous = @user.groups.pluck(:id).to_set
    @user.groups = new_groups
    added   = new_ids.to_set - previous
    removed = previous - new_ids.to_set
    if added.any? || removed.any?
      audit_privilege_change!("groups_updated", user: @user, metadata: {
        username: @user.username,
        added: Group.where(id: added.to_a).pluck(:name),
        removed: Group.where(id: removed.to_a).pluck(:name)
      })
    end
    redirect_to user_path(@user), notice: "Group memberships updated."
  end

  def update_teams
    new_ids = Array(params[:team_ids]).reject(&:blank?).map(&:to_i)
    previous = @user.teams.pluck(:id).to_set
    @user.teams = Team.where(id: new_ids).to_a
    added   = new_ids.to_set - previous
    removed = previous - new_ids.to_set
    if added.any? || removed.any?
      audit_privilege_change!("teams_updated", user: @user, metadata: {
        username: @user.username,
        added: Team.where(id: added.to_a).pluck(:name),
        removed: Team.where(id: removed.to_a).pluck(:name)
      })
    end
    redirect_to user_path(@user), notice: "Team memberships updated."
  end

  private

  def load_user
    @user = User.find(params[:id])
  end
end
