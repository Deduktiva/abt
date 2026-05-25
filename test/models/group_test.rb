require "test_helper"

class GroupTest < ActiveSupport::TestCase
  test "requires name" do
    group = Group.new
    refute group.valid?
    assert_includes group.errors[:name], "can't be blank"
  end

  test "permissions= syncs the join table" do
    group = Group.create!(name: "Test Group")
    group.permissions = %w[customers.view invoices.view]
    group.reload
    assert_equal %w[customers.view invoices.view].sort, group.permissions.to_a.sort
    group.permissions = %w[customers.view products.view]
    group.reload
    assert_equal %w[customers.view products.view].sort, group.permissions.to_a.sort
  end

  test "permissions= ignores unknown keys" do
    group = Group.create!(name: "Test Group")
    group.permissions = %w[customers.view not.a.real.perm]
    group.reload
    assert_equal %w[customers.view], group.permissions.to_a
  end

  test "permission? checks membership" do
    group = Group.create!(name: "Test Group")
    group.permissions = %w[customers.view]
    assert group.permission?("customers.view")
    refute group.permission?("customers.edit")
  end

  test "built-in group cannot be destroyed" do
    admin = groups(:admin)
    refute admin.destroy
    assert_includes admin.errors[:base], "Cannot delete a built-in group"
    assert Group.exists?(admin.id)
  end

  test "non-built-in group can be destroyed" do
    sales = groups(:sales)
    assert sales.destroy
    refute Group.exists?(sales.id)
  end

  test "admin? recognizes the built-in Admin" do
    assert groups(:admin).admin?
    refute groups(:sales).admin?
  end

  test "admin-only permissions cannot be assigned to non-Admin groups" do
    sales = groups(:sales)
    gp = sales.group_permissions.build(permission: "users.reset_passkeys")
    refute gp.valid?
    assert_match(/can only be granted to the built-in Admin group/, gp.errors[:permission].first)

    gp2 = sales.group_permissions.build(permission: "users.auto_confirm_email")
    refute gp2.valid?
  end

  test "permissions= silently drops admin-only keys for non-Admin groups" do
    sales = groups(:sales)
    sales.permissions = %w[customers.view users.reset_passkeys users.auto_confirm_email]
    sales.reload
    refute_includes sales.permissions, "users.reset_passkeys"
    refute_includes sales.permissions, "users.auto_confirm_email"
    assert_includes sales.permissions, "customers.view"
  end

  test "admin-only permissions can attach to the Admin group" do
    admin = groups(:admin)
    # Both are already attached via fixtures.
    assert_includes admin.permissions, "users.reset_passkeys"
    assert_includes admin.permissions, "users.auto_confirm_email"
  end

  # Renaming the Admin group would silently disable Group#admin? — the
  # last-admin protection, the admin-only permission validation, and the
  # permission filter in Group#permissions= all key off `name == "Admin"`.
  test "built-in group name cannot be changed at the model layer" do
    admin = groups(:admin)
    admin.name = "Renamed"
    refute admin.valid?
    assert_includes admin.errors[:name], "of a built-in group cannot be changed"
    assert_equal "Admin", admin.reload.name
  end

  test "non-built-in groups can be renamed" do
    sales = groups(:sales)
    assert sales.update(name: "Renamed Sales")
    assert_equal "Renamed Sales", sales.reload.name
  end

  test "description on a built-in group can still be edited" do
    admin = groups(:admin)
    assert admin.update(description: "Updated description")
    assert_equal "Updated description", admin.reload.description
  end
end
