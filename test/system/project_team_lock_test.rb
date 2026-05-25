require "application_system_test_case"

# Regression coverage for the customer→team locking on the project form.
# The Stimulus controller MUST find both the customer and teamSelect
# targets — if they live in sibling rows that the controller's element
# doesn't enclose, `hasTeamSelectTarget` returns false and the lock
# silently no-ops while the dropdown keeps offering every team. The form
# server-side validation still rejects the bad submission, but the UI
# becomes a trap.
class ProjectTeamLockTest < ApplicationSystemTestCase
  setup do
    @acme_team = teams(:acme)
    # Alice is in fixtures with bypass_team_scoping (Admin group), so the
    # raw team dropdown contains every team — the most aggressive case for
    # the lock to filter down.
    @customer = customers(:good_eu) # team: default per fixture
  end

  test "selecting a customer narrows the team dropdown to that customer's team" do
    visit new_project_path

    team_options = -> { find("select[name='project[team_id]']").all("option").map(&:value).reject(&:empty?) }

    # No customer yet → the bypass-admin sees every team option.
    assert_includes team_options.call, @acme_team.id.to_s,
                    "with no customer selected, Acme should be an option for an admin user"

    select @customer.name, from: "project[bill_to_customer_id]"

    # Wait for the filter to take effect: the only option should be Default.
    assert_selector "select[name='project[team_id]'] option", count: 1
    refute_includes team_options.call, @acme_team.id.to_s,
                    "Acme should no longer appear once a Default-team customer is selected"
    assert_equal [ @customer.team_id.to_s ], team_options.call
  end

  test "clearing the customer restores the full team list" do
    visit new_project_path
    select @customer.name, from: "project[bill_to_customer_id]"
    assert_selector "select[name='project[team_id]'] option", count: 1

    select "No customer (reusable project)", from: "project[bill_to_customer_id]"

    # Multiple options back in play once we're reusable (and Acme is one of them).
    team_values = find("select[name='project[team_id]']").all("option").map(&:value).reject(&:empty?)
    assert_includes team_values, @acme_team.id.to_s
    assert_includes team_values, teams(:default).id.to_s
  end
end
