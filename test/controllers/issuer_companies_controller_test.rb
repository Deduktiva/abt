require "test_helper"

class IssuerCompaniesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get issuer_companies_show_url
    assert_response :success
  end

  test "should get edit" do
    get issuer_companies_edit_url
    assert_response :success
  end

  test "should get update" do
    get issuer_companies_update_url
    assert_response :success
  end
end
