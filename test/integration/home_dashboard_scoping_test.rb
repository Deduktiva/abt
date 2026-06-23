require "test_helper"

# Regression test: home dashboard aggregates must be scoped to the
# current_user's visible invoices, not the whole database.
class HomeDashboardScopingTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  test "admin sees aggregates over all invoices" do
    sign_in_as(users(:alice))
    get root_path
    assert_response :success
    # Alice bypasses team scoping; smoke check the page renders.
  end

  test "user in no teams sees zero aggregates" do
    # blocked_carol has no team_memberships and no group memberships, so
    # un-block her so she can sign in but still has no permissions/teams.
    carol = users(:blocked_carol)
    carol.unblock!(actor: users(:alice), reason: "test setup")

    sign_in_as(carol)
    get root_path
    assert_response :success
    assert_select "h2.text-primary", text: "0"
    # Currency totals start with the EUR symbol; check for the zero amount.
    assert_select "h2.text-success", text: /€\s*0\.00\z/
  end
end
