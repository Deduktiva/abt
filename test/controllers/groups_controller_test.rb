require "test_helper"

class GroupsControllerTest < ActionDispatch::IntegrationTest
  test "admin can list groups" do
    get groups_path
    assert_response :success
    assert_select "h1", text: "Groups"
  end

  test "non-admin is denied" do
    sign_in_as(users(:bob))
    get groups_path
    assert_redirected_to root_path
  end

  test "admin can create a group with permissions and members" do
    assert_difference "Group.count", 1 do
      post groups_path, params: {
        group: {
          name: "Bookkeeping",
          description: "Books and invoices",
          bypass_team_scoping: false,
          permission_keys: %w[invoices.view invoices.edit],
          user_ids: [ users(:bob).id ]
        }
      }
    end
    assert_redirected_to groups_path
    group = Group.find_by(name: "Bookkeeping")
    assert_equal %w[invoices.edit invoices.view].sort, group.permissions.to_a.sort
    assert_includes group.users, users(:bob)
  end

  test "admin can update a group" do
    group = groups(:sales)
    patch group_path(group), params: {
      group: { name: "Sales Renamed", description: "X", permission_keys: %w[customers.view], user_ids: [] }
    }
    assert_redirected_to groups_path
    assert_equal "Sales Renamed", group.reload.name
    assert_equal %w[customers.view], group.permissions.to_a
  end

  test "built-in admin group cannot be deleted" do
    admin = groups(:admin)
    assert_no_difference "Group.count" do
      delete group_path(admin)
    end
  end

  test "non-built-in group can be deleted" do
    sales = groups(:sales)
    assert_difference "Group.count", -1 do
      delete group_path(sales)
    end
  end

  test "bypass_team_scoping cannot be set from the form (privilege escalation guard)" do
    post groups_path, params: {
      group: {
        name: "Sneaky",
        description: "tries to bypass",
        bypass_team_scoping: true,
        permission_keys: [],
        user_ids: []
      }
    }
    sneaky = Group.find_by(name: "Sneaky")
    refute sneaky.bypass_team_scoping?
  end

  test "bypass_team_scoping cannot be enabled on update either" do
    sales = groups(:sales)
    refute sales.bypass_team_scoping?
    patch group_path(sales), params: {
      group: { name: sales.name, description: sales.description, bypass_team_scoping: true }
    }
    refute sales.reload.bypass_team_scoping?
  end

  test "admin-only permissions cannot be granted to a non-Admin group via the form" do
    sales = groups(:sales)
    patch group_path(sales), params: {
      group: {
        name: sales.name,
        description: sales.description,
        permission_keys: %w[customers.view users.reset_passkeys users.auto_confirm_email]
      }
    }
    sales.reload
    refute_includes sales.permissions, "users.reset_passkeys"
    refute_includes sales.permissions, "users.auto_confirm_email"
    assert_includes sales.permissions, "customers.view"
  end

  test "creating a group with admin-only permissions strips them" do
    post groups_path, params: {
      group: {
        name: "Helpdesk",
        description: "tries to grab credential primitives",
        permission_keys: %w[users.view users.reset_passkeys users.auto_confirm_email]
      }
    }
    helpdesk = Group.find_by(name: "Helpdesk")
    refute_nil helpdesk
    assert_includes helpdesk.permissions, "users.view"
    refute_includes helpdesk.permissions, "users.reset_passkeys"
    refute_includes helpdesk.permissions, "users.auto_confirm_email"
  end

  # Defense against renaming the built-in Admin group via PATCH /groups/:id.
  # If the rename succeeded, Group#admin? (builtin? && name == "Admin")
  # would silently return false on the next request, disabling the
  # last-admin protection, admin-only permission validation, and the
  # permission filter in Group#permissions=.
  test "PATCH cannot rename the built-in Admin group" do
    admin = groups(:admin)
    patch group_path(admin), params: { group: { name: "Renamed", description: admin.description } }
    admin.reload
    assert_equal "Admin", admin.name
    # admin? still resolves correctly so the security checks still fire.
    assert admin.admin?
  end

  test "PATCH can rename a non-built-in group" do
    # Sanity check that the controller filter only suppresses name changes
    # for built-in groups, not all groups.
    sales = groups(:sales)
    patch group_path(sales), params: { group: { name: "Renamed Sales", description: sales.description } }
    assert_equal "Renamed Sales", sales.reload.name
  end

  # Privilege escalation guard for the other path: a `groups.manage` holder
  # that isn't an admin must not be able to add themselves (or anyone) to
  # the Admin group by editing the Admin group's member list.
  test "non-admin with groups.manage cannot add members to the Admin group" do
    helpdesk = Group.create!(name: "Helpdesk", description: "groups.manage only")
    helpdesk.permissions = %w[groups.manage]
    helpdesk.users << users(:bob)

    sign_in_as(users(:bob))
    patch group_path(groups(:admin)), params: {
      group: { description: groups(:admin).description,
               user_ids: [ users(:alice).id, users(:bob).id ] }
    }
    refute_includes groups(:admin).reload.users, users(:bob)
  end

  # Symmetric guard: a non-admin must not be able to REMOVE admins by
  # editing the Admin group's member list either. Without this guard, a
  # single PATCH with one admin id in user_ids would silently delete every
  # other admin's GroupMembership (has_many through swallows the
  # prevent_removing_last_admin abort for non-final rows).
  test "non-admin with groups.manage cannot remove members from the Admin group" do
    helpdesk = Group.create!(name: "Helpdesk", description: "groups.manage only")
    helpdesk.permissions = %w[groups.manage]
    helpdesk.users << users(:bob)

    # Add a second admin so a partial removal wouldn't trip the last-admin floor.
    second_admin = User.create!(username: "second_admin", full_name: "Second Admin",
                                webauthn_id: "second-admin-webauthn-id")
    groups(:admin).users << second_admin

    sign_in_as(users(:bob))
    patch group_path(groups(:admin)), params: {
      group: { description: groups(:admin).description,
               user_ids: [ users(:alice).id ] }
    }
    assert_includes groups(:admin).reload.users, second_admin
  end
end
