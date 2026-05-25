require "test_helper"

class PermissionTest < ActiveSupport::TestCase
  test "ALL contains expected categories" do
    assert_includes Permission::CATEGORIES, "Operations"
    assert_includes Permission::CATEGORIES, "Administration"
  end

  test "ALL_KEYS contains the canonical permissions" do
    %w[customers.view customers.edit invoices.edit groups.manage teams.manage].each do |key|
      assert_includes Permission::ALL_KEYS, key
    end
  end

  test "valid? returns true for known keys" do
    assert Permission.valid?("customers.view")
    refute Permission.valid?("not.a.permission")
    refute Permission.valid?("")
  end

  test "label_for returns a human label for a known key" do
    assert_equal "View customers", Permission.label_for("customers.view")
    assert_equal "unknown.key", Permission.label_for("unknown.key")
  end

  test "grouped returns entries by category" do
    grouped = Permission.grouped
    assert grouped["Operations"].any? { |e| e.key == "customers.view" }
    assert grouped["Administration"].any? { |e| e.key == "groups.manage" }
  end

  test "admin-only keys are flagged" do
    assert Permission.admin_only?("users.reset_passkeys")
    assert Permission.admin_only?("users.auto_confirm_email")
    refute Permission.admin_only?("users.view")
    refute Permission.admin_only?("users.block")
  end

  test "ADMIN_ONLY_KEYS contains the credential-issuance permissions" do
    assert_equal %w[users.reset_passkeys users.auto_confirm_email].sort,
                 Permission::ADMIN_ONLY_KEYS.to_a.sort
  end
end
