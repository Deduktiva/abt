require "test_helper"

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  test "renders tiles for every section the user can view" do
    get configuration_path
    assert_response :success
    assert_select ".breadcrumb-item.active", text: "Configuration"
    assert_select ".config-tile", text: /Issuer Company/
    assert_select ".config-tile", text: /Product Catalog/
    assert_select ".config-tile", text: /Sales Tax/
    assert_select ".config-tile", text: /Users/
    assert_select ".config-tile", text: /Groups/
    assert_select ".config-tile", text: /Teams/
    assert_select ".config-tile", text: /Background Jobs/
  end

  test "redirects a user with none of the configuration permissions" do
    sign_in_as(users(:bob))
    get configuration_path
    assert_redirected_to root_path
  end
end
