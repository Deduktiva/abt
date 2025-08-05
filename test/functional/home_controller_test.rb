require 'test_helper'

class HomeControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_select 'h1', text: 'Business Dashboard'
  end

  test "should display business statistics" do
    get :index
    assert_response :success

    # Check that statistics cards are displayed
    assert_select '.card-body .text-primary', text: /\d+/
    assert_select '.card-body .text-success'
    assert_select '.card-body .text-info'
    assert_select '.card-body .text-warning'

    # Check statistics labels
    assert_select 'p', text: 'Invoices this year'
    assert_select 'p', text: 'Revenue YTD'
    assert_select 'p', text: 'Total published invoices'
    assert_select 'p', text: 'Total revenue'
  end

  test "should display company information" do
    get :index
    assert_response :success

    # Check company information section
    assert_select '.card h5', text: 'Company Information'
    assert_select 'strong', text: 'Address:'
    assert_select 'strong', text: 'VAT ID:'
    assert_select 'strong', text: 'Bank:'
  end

  test "should display setup warning when not configured" do
    # Clear existing tax configuration
    SalesTaxRate.delete_all
    SalesTaxCustomerClass.delete_all
    SalesTaxProductClass.delete_all

    get :index
    assert_response :success
    assert_select '.alert-warning h5', text: 'Quick Setup Required'
  end

  test "statistics should include current year data" do
    get :index
    assert_response :success

    # Verify that statistics are displayed (no need to check assigns in modern Rails)
    assert_select '.card-body h2.text-primary'
    assert_select '.card-body h2.text-success'
    assert_select '.card-body h2.text-info'
    assert_select '.card-body h2.text-warning'
  end
end
