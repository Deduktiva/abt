require "test_helper"

class UsersMembershipTest < ActionDispatch::IntegrationTest
  test "admin can update group memberships" do
    bob = users(:bob)
    patch update_groups_user_path(bob), params: { group_ids: [ groups(:sales).id ] }
    assert_redirected_to user_path(bob)
    assert_includes bob.reload.groups, groups(:sales)
  end

  test "admin can update team memberships" do
    bob = users(:bob)
    patch update_teams_user_path(bob), params: { team_ids: [ teams(:acme).id ] }
    assert_redirected_to user_path(bob)
    assert_equal [ teams(:acme).id ], bob.reload.team_ids
  end

  test "cannot remove the last admin" do
    alice = users(:alice)
    # Try to remove alice from admin while she is the only admin member.
    patch update_groups_user_path(alice), params: { group_ids: [] }
    assert_redirected_to user_path(alice)
    assert_includes alice.reload.groups, groups(:admin)
  end

  test "non-admin cannot update group memberships" do
    sign_in_as(users(:bob))
    patch update_groups_user_path(users(:bob)), params: { group_ids: [] }
    assert_redirected_to root_path
  end

  # Privilege escalation guard: a `groups.manage` holder is NOT an admin
  # and must not be able to self-promote (or promote anyone else) into the
  # Admin group via PATCH /users/:id/update_groups. Admin membership confers
  # bypass_team_scoping plus the admin-only credential primitives.
  test "non-admin with groups.manage cannot promote themselves to Admin" do
    helpdesk = Group.create!(name: "Helpdesk", description: "groups.manage only")
    helpdesk.permissions = %w[groups.manage]
    helpdesk.users << users(:bob)

    sign_in_as(users(:bob))
    patch update_groups_user_path(users(:bob)), params: {
      group_ids: [ helpdesk.id, groups(:admin).id ]
    }
    assert_redirected_to user_path(users(:bob))
    refute_includes users(:bob).reload.groups, groups(:admin)
  end

  test "non-admin with groups.manage cannot promote another user to Admin" do
    helpdesk = Group.create!(name: "Helpdesk", description: "groups.manage only")
    helpdesk.permissions = %w[groups.manage]
    helpdesk.users << users(:bob)

    sign_in_as(users(:bob))
    target = User.create!(username: "target", full_name: "Target User",
                          webauthn_id: "target-webauthn-id")
    patch update_groups_user_path(target), params: {
      group_ids: [ groups(:admin).id ]
    }
    assert_redirected_to user_path(target)
    refute_includes target.reload.groups, groups(:admin)
  end

  # Symmetric to the add-direction guard: a non-admin holder of groups.manage
  # must not be able to demote an existing admin via update_groups either.
  # The last-admin floor protects only the final row; without this guard a
  # non-admin could pick off admins one at a time down to the floor.
  test "non-admin with groups.manage cannot remove another user from Admin" do
    helpdesk = Group.create!(name: "Helpdesk", description: "groups.manage only")
    helpdesk.permissions = %w[groups.manage]
    helpdesk.users << users(:bob)

    # Promote a second admin so removing the original wouldn't trip the
    # last-admin guard.
    second_admin = User.create!(username: "second_admin", full_name: "Second Admin",
                                webauthn_id: "second-admin-webauthn-id")
    groups(:admin).users << second_admin

    sign_in_as(users(:bob))
    patch update_groups_user_path(users(:alice)), params: { group_ids: [] }
    assert_redirected_to user_path(users(:alice))
    assert_includes users(:alice).reload.groups, groups(:admin)
  end
end
