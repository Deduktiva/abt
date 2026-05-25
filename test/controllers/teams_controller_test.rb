require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  test "admin can list teams" do
    get teams_path
    assert_response :success
    assert_select "h1", text: "Teams"
  end

  test "non-admin is denied" do
    sign_in_as(users(:bob))
    get teams_path
    assert_redirected_to root_path
  end

  test "admin can create a team" do
    assert_difference "Team.count", 1 do
      post teams_path, params: {
        team: { name: "EU", description: "EU customers", user_ids: [ users(:bob).id ] }
      }
    end
    new_team = Team.find_by(name: "EU")
    assert_includes new_team.users, users(:bob)
  end

  test "built-in default team cannot be deleted" do
    default = teams(:default)
    assert_no_difference "Team.count" do
      delete team_path(default)
    end
  end

  test "team in use cannot be deleted" do
    # Acme has no customers/projects in fixtures, so add one.
    Customer.create!(
      matchcode: "IN_USE_TEAM",
      name: "In Use",
      vat_id: "EU151515151",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: teams(:acme)
    )
    assert_no_difference "Team.count" do
      delete team_path(teams(:acme))
    end
  end
end
