require 'test_helper'

class CustomersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @customer = customers(:good_eu)
  end

  test "should get index" do
    get customers_url
    assert_response :success
    assert_select 'h1', text: /customers/i
  end

  test "should get show" do
    get customer_url(@customer)
    assert_response :success
    assert_select 'h1', text: /Customer/
  end

  test "should get new" do
    get new_customer_url
    assert_response :success
    assert_select 'form'
  end

  test "should create customer" do
    assert_difference('Customer.count') do
      post customers_url, params: {
        customer: {
          matchcode: 'TEST123',
          name: 'Test Company',
          sales_tax_customer_class_id: @customer.sales_tax_customer_class_id
        }
      }
    end
    assert_redirected_to customer_url(Customer.last)
  end

  test "should delete unused customer" do
    # Create a new customer that hasn't been used
    unused_customer = Customer.create!(
      matchcode: 'UNUSED',
      name: 'Unused Customer',
      sales_tax_customer_class: @customer.sales_tax_customer_class
    )

    assert_difference('Customer.count', -1) do
      delete customer_url(unused_customer)
    end
    assert_redirected_to customers_url
    follow_redirect!
    assert_select '.alert-success', text: /successfully deleted/
  end

  test "should not delete customer used in invoices" do
    # Use the good_eu customer which has invoices
    used_customer = customers(:good_eu)

    # Ensure it has invoices
    assert used_customer.used_in_invoices?, "Customer should have invoices for this test"

    assert_no_difference('Customer.count') do
      delete customer_url(used_customer)
    end
    assert_redirected_to customers_url
    follow_redirect!
    assert_select '.alert-danger', text: /Cannot delete customer that has been used in invoices/
  end

  test "customer deletion prevention logic works" do
    # Test that unused customer can be deleted
    unused_customer = Customer.create!(
      matchcode: 'UNUSED2',
      name: 'Another Unused Customer',
      sales_tax_customer_class: @customer.sales_tax_customer_class
    )
    assert_not unused_customer.used_in_invoices?

    # Test that used customer cannot be deleted
    used_customer = customers(:good_eu)
    assert used_customer.used_in_invoices?
  end

  test "should show used indicator in index for customers with invoices" do
    get customers_url
    assert_response :success

    # Check that used customers show "Used" instead of delete link
    assert_select 'span.text-muted', text: 'Used'
  end

  test "should filter customers by active status" do
    # Create inactive customer
    inactive_customer = Customer.create!(
      matchcode: 'INACTIVE',
      name: 'Inactive Customer',
      active: false,
      sales_tax_customer_class: @customer.sales_tax_customer_class
    )

    # Test showing all customers
    get customers_url
    assert_response :success
    assert_select 'td', text: 'INACTIVE'

    # Test showing only active customers
    get customers_url(filter: 'active')
    assert_response :success
    assert_select 'td', text: 'INACTIVE', count: 0

    # Test showing only inactive customers
    get customers_url(filter: 'inactive')
    assert_response :success
    assert_select 'td', text: 'INACTIVE'
  end

  test "should show active status in show page" do
    get customer_url(@customer)
    assert_response :success
    assert_select 'span.badge.bg-success', text: 'Yes'
  end

  test "should allow updating customer active status" do
    patch customer_url(@customer), params: {
      customer: { active: false }
    }
    assert_redirected_to customer_url(@customer)

    @customer.reload
    assert_not @customer.active?
  end
end