require "test_helper"

class PermissionsEnforcementTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  test "admin can reach all main sections" do
    sign_in_as(users(:alice))
    [ customers_path, projects_path, invoices_path, delivery_notes_path,
     products_path, sales_tax_rates_path, issuer_company_path, users_path,
     user_invites_path, groups_path, teams_path, jobs_status_path ].each do |path|
      get path
      assert_response :success, "expected admin to load #{path}, got #{response.status}"
    end
  end

  test "user without permissions is denied with redirect" do
    sign_in_as(users(:bob))
    [ customers_path, invoices_path, products_path, sales_tax_rates_path,
     issuer_company_path, users_path, user_invites_path, groups_path,
     teams_path, jobs_status_path ].each do |path|
      get path
      assert_response :redirect, "expected redirect for #{path}, got #{response.status}"
      assert_redirected_to root_path
    end
  end

  test "user with partial permissions reaches granted sections only" do
    bob = users(:bob)
    bob.groups << groups(:sales)

    sign_in_as(bob)
    get customers_path
    assert_response :success
    get invoices_path
    assert_response :success

    get products_path
    assert_redirected_to root_path
    get groups_path
    assert_redirected_to root_path
  end

  test "navigation hides items the user cannot access" do
    sign_in_as(users(:bob))
    get root_path
    assert_response :success
    assert_no_match(/href="#{customers_path}"/, response.body)
    assert_no_match(/href="#{groups_path}"/, response.body)

    bob = users(:bob)
    bob.groups << groups(:sales)
    sign_in_as(bob)
    get root_path
    assert_response :success
    assert_match(/href="#{customers_path}"/, response.body)
    # No groups.manage perm yet.
    assert_no_match(/href="#{groups_path}"/, response.body)
  end

  test "admin sees groups and teams links in navigation" do
    sign_in_as(users(:alice))
    get root_path
    assert_response :success
    assert_match(/href="#{groups_path}"/, response.body)
    assert_match(/href="#{teams_path}"/, response.body)
  end
end
