require "test_helper"

class UserPermissionTest < ActiveSupport::TestCase
  test "admin user has all permissions and bypasses team scoping" do
    alice = users(:alice)
    assert alice.bypass_team_scoping?
    Permission::ALL_KEYS.each do |key|
      assert alice.permission?(key), "alice should have #{key}"
    end
  end

  test "non-admin user starts with no permissions" do
    bob = users(:bob)
    refute bob.bypass_team_scoping?
    refute bob.permission?("customers.view")
    refute bob.permission?("groups.manage")
  end

  test "group membership grants the permissions of that group" do
    bob = users(:bob)
    bob.groups << groups(:sales)
    bob.reload
    # sales has customers.view + customers.edit + invoices.view + invoices.edit
    assert bob.permission?("customers.view")
    assert bob.permission?("customers.edit")
    assert bob.permission?("invoices.view")
    refute bob.permission?("groups.manage")
  end

  test "User#permissions emits DISTINCT and dedupes across groups" do
    bob = users(:bob)
    overlap = Group.create!(name: "Overlap", description: "Test overlap group")
    overlap.group_permissions.create!(permission: "customers.view")
    overlap.group_permissions.create!(permission: "invoices.view")
    bob.groups << groups(:sales)
    bob.groups << overlap
    bob.reload

    assert bob.permission?("customers.view")
    assert bob.permission?("invoices.view")

    # Regression guard for #338: capture the SQL the production code
    # actually issues and require it to deduplicate at the database
    # level. Without DISTINCT, a user in two groups that both grant
    # customers.view receives two rows for that key.
    queries = []
    callback = ->(_name, _start, _finish, _id, payload) {
      sql = payload[:sql]
      queries << sql if sql.include?("group_permissions") &&
                        sql.include?("group_memberships")
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      bob.instance_variable_set(:@permissions, nil)
      bob.permissions
    end

    refute_empty queries, "expected User#permissions to query group_permissions"
    assert queries.any? { |q| q =~ /SELECT\s+DISTINCT/i },
           "User#permissions must emit SELECT DISTINCT; got: #{queries.inspect}"
  end

  test "visible_team_ids returns all teams for bypass users" do
    assert_equal Team.pluck(:id).sort, users(:alice).visible_team_ids.sort
  end

  test "visible_team_ids only returns member teams for non-bypass users" do
    assert_equal users(:bob).team_ids.sort, users(:bob).visible_team_ids.sort
  end

  test "auto_promote_first_user adds to admin when this is the only user" do
    new_user = User.create!(
      username: "pioneer",
      full_name: "Pioneer",
      webauthn_id: "pioneer-id"
    )
    # The fixture users still exist, so the callback didn't fire on create.
    refute_includes new_user.groups, groups(:admin)
    # Exercise the callback by simulating User.count == 1.
    User.singleton_class.define_method(:count) { 1 }
    begin
      new_user.send(:auto_promote_first_user)
    ensure
      User.singleton_class.send(:remove_method, :count)
    end
    assert_includes new_user.reload.groups, groups(:admin)
  end

  test "subsequent users are not auto-promoted" do
    new_user = User.create!(
      username: "plebs",
      full_name: "Plebs",
      webauthn_id: "plebs-id"
    )
    assert_empty new_user.groups
  end

  test "every new user is auto-added to the Default team" do
    new_user = User.create!(
      username: "joiner",
      full_name: "Joiner",
      webauthn_id: "joiner-id"
    )
    assert_includes new_user.teams, teams(:default)
  end

  test "first user lands in both Admin group and Default team" do
    new_user = User.create!(
      username: "pioneer2",
      full_name: "Pioneer 2",
      webauthn_id: "pioneer-2-id"
    )
    # join_default_team fires unconditionally
    assert_includes new_user.teams, teams(:default)
    # auto_promote_first_user only fires when this is actually the first user
    User.singleton_class.define_method(:count) { 1 }
    begin
      new_user.send(:auto_promote_first_user)
    ensure
      User.singleton_class.send(:remove_method, :count)
    end
    new_user.reload
    assert_includes new_user.groups, groups(:admin)
    assert_includes new_user.teams, teams(:default)
  end
end
