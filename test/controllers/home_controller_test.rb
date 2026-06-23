require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should display home page with business statistics and dashboard" do
    get root_url
    assert_response :success
    assert_select "h1", text: "Business Dashboard"

    # Check that statistics cards are displayed
    assert_select ".card-body .text-primary", text: /\d+/
  end

  test "should display setup warning when not configured" do
    # Clear existing tax configuration
    SalesTaxRate.delete_all
    SalesTaxCustomerClass.delete_all
    SalesTaxProductClass.delete_all

    get root_url
    assert_response :success
    assert_select ".alert-warning h5", text: "Quick Setup Required"
  end

  test "should display setup warning when no default product class is set" do
    SalesTaxProductClass.update_all(is_default: false)

    get root_url
    assert_response :success
    assert_select ".alert-warning h5", text: "Quick Setup Required"
  end
end
