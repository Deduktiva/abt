require "test_helper"

class DashboardConsistencyChecksTest < ActiveSupport::TestCase
  # Build args that match the configured AbsoluteUrl settings, so the URL
  # check is silent unless a test deliberately diverges one field.
  def matching_request
    { host: Settings.app.host, protocol: Settings.app.protocol, script_name: Settings.app.script_name }
  end

  def issues(overrides = {})
    DashboardConsistencyChecks.new(**matching_request.merge(overrides)).issues
  end

  def issue(key, overrides = {})
    issues(overrides).find { |i| i.key == key }
  end

  test "no issues when the Admin group is complete and the URL matches" do
    assert_empty issues
  end

  test "flags the Admin group missing a permission" do
    groups(:admin).group_permissions.where(permission: "delivery_notes.review_acceptance").delete_all

    found = issue(:admin_permissions)
    assert found
    assert_includes found.details.join(" "), Permission.label_for("delivery_notes.review_acceptance")
    assert found.fix_path
  end

  test "no permission issue when the Admin group has every permission" do
    assert_nil issue(:admin_permissions)
  end

  test "flags a script_name mismatch" do
    found = issue(:absolute_url, script_name: "/wrong-prefix")
    assert found
    assert_includes found.details.join(" "), "/wrong-prefix"
  end

  test "flags host and protocol mismatches" do
    found = issue(:absolute_url, host: "elsewhere.example.com", protocol: "ftp")
    assert found
    assert_includes found.details.join(" "), "elsewhere.example.com"
    assert_includes found.details.join(" "), "ftp"
  end

  test "tolerates script_name trailing slash, host case, and host port differences" do
    assert_nil issue(:absolute_url,
                     script_name: Settings.app.script_name.to_s + "/",
                     host: Settings.app.host.to_s.upcase.sub(/:\d+\z/, "") + ":9999")
  end
end
