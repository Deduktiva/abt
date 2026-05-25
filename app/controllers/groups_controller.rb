class GroupsController < ApplicationController
  before_action -> { require_permission!("groups.manage") }
  before_action :load_group, only: [ :show, :edit, :update, :destroy ]

  def index
    @groups = Group.ordered
                   .left_joins(:group_memberships, :group_permissions)
                   .select('groups.*,
                            COUNT(DISTINCT group_memberships.id) AS member_count,
                            COUNT(DISTINCT group_permissions.id) AS permission_count')
                   .group("groups.id")
  end

  def show
    @members = @group.users.order(:username)
    @permissions = @group.permissions.to_a.sort
  end

  def new
    @group = Group.new
  end

  def edit
  end

  def create
    @group = Group.new(group_attributes)

    if @group.save
      assign_permissions(@group, params.dig(:group, :permission_keys))
      assign_members(@group, params.dig(:group, :user_ids))
      audit_privilege_change!("group_created", metadata: { name: @group.name,
                                          permissions: @group.permissions.to_a,
                                          bypass_team_scoping: @group.bypass_team_scoping?,
                                          member_usernames: @group.users.pluck(:username) })
      redirect_to groups_path, notice: "Group created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    before_perms = @group.permissions.dup
    before_members = @group.user_ids.to_set
    before_bypass = @group.bypass_team_scoping?
    if @group.update(group_attributes)
      assign_permissions(@group, params.dig(:group, :permission_keys)) if params.dig(:group, :permission_keys)
      assign_members(@group, params.dig(:group, :user_ids)) if params.dig(:group, :user_ids)
      after_perms = @group.permissions
      after_members = @group.reload.user_ids.to_set
      audit_privilege_change!("group_updated", metadata: {
        name: @group.name,
        permissions_added: (after_perms - before_perms).to_a,
        permissions_removed: (before_perms - after_perms).to_a,
        members_added: User.where(id: (after_members - before_members).to_a).pluck(:username),
        members_removed: User.where(id: (before_members - after_members).to_a).pluck(:username),
        bypass_team_scoping_changed: before_bypass != @group.bypass_team_scoping?
      })
      redirect_to groups_path, notice: "Group updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    name = @group.name
    if @group.destroy
      audit_privilege_change!("group_deleted", metadata: { name: name })
      redirect_to groups_path, notice: "Group deleted."
    else
      redirect_to groups_path, alert: @group.errors.full_messages.join(", ")
    end
  end

  private

  def load_group
    @group = Group.find(params[:id])
  end

  # bypass_team_scoping is intentionally NOT permitted from user input. It is
  # the most dangerous flag in the system — set on the Admin group via
  # migration/seed and nowhere else. Granting it from a web form would let
  # any `groups.manage` user create a "bypass" group, join it, and read every
  # team's data. Operators that need another bypass group must do it via a
  # migration.
  #
  # :name is also stripped for built-in groups. Group#admin? identifies the
  # Admin group by `builtin? && name == "Admin"`, so renaming it would silently
  # disable the last-admin protection, the admin-only permission validation,
  # and the permission filter in Group#permissions=. The view marks the field
  # readonly; this is the server-side counterpart.
  def group_attributes
    attrs = params.require(:group).permit(:name, :description)
    attrs.delete(:name) if @group&.builtin?
    attrs
  end

  def assign_permissions(group, keys)
    return if group.builtin? # cannot modify built-in Admin permissions
    # Admin-only permissions (users.reset_passkeys, users.auto_confirm_email)
    # are stripped before assignment so a tampered form submission can't
    # grant them to a non-Admin group. GroupPermission validation re-checks.
    keys = Array(keys).reject(&:blank?) - Permission::ADMIN_ONLY_KEYS.to_a
    group.permissions = keys
  end

  def assign_members(group, user_ids)
    new_ids = Array(user_ids).reject(&:blank?).map(&:to_i)
    new_users = User.where(id: new_ids).to_a

    if group.admin? && new_users.empty?
      group.errors.add(:base, "Admin group must have at least one member")
      return
    end

    # Only existing admins can change the Admin group's membership in either
    # direction. Without this, a `groups.manage` user could grant themselves
    # Admin membership (inheriting bypass_team_scoping + the admin-only
    # credential primitives) OR demote other admins. The remove direction is
    # the more dangerous primitive: `has_many through` collection assignment
    # silently swallows `prevent_removing_last_admin`'s `throw :abort`, so a
    # single PATCH with one admin id in user_ids would otherwise delete every
    # other admin's GroupMembership without raising.
    if group.admin? && !current_user.groups.include?(group)
      added   = new_users.map(&:id) - group.user_ids
      removed = group.user_ids - new_users.map(&:id)
      if added.any? || removed.any?
        group.errors.add(:base, "Only members of the Admin group can change its membership")
        return
      end
    end

    group.users = new_users
  end
end
