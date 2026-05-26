require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @customer = customers(:good_eu)
  end

  test "should get index" do
    get customers_url(filter: "all")
    assert_response :success
    assert_select "table tr", count: Customer.count + 1 # +1 for header row
  end

  test "should get show" do
    get customer_url(@customer)
    assert_response :success
    assert_select ".breadcrumb-item", text: "Customers"
    assert_select ".breadcrumb-item.active", text: @customer.matchcode
  end

  test "should get new" do
    get new_customer_url
    assert_response :success
    assert_select "form"
  end

  test "new customer form marks required fields and lets the browser validate them" do
    get new_customer_url
    assert_response :success

    assert_select "form#new_customer:not([novalidate])"

    assert_select "input#customer_matchcode[required]"
    assert_select "textarea#customer_name[required]"

    assert_select "label.required[for='customer_team_id']"
    assert_select "label.required[for='customer_sales_tax_customer_class_id']"
    assert_select "label.required[for='customer_language_id']"
  end

  test "should create customer" do
    assert_difference("Customer.count") do
      post customers_url, params: {
        customer: {
          matchcode: "TEST123",
          name: "Test Company",
          vat_id: "EU181818181",
          sales_tax_customer_class_id: @customer.sales_tax_customer_class_id,
          team_id: teams(:default).id
        }
      }
    end
    assert_redirected_to customer_url(Customer.last)
  end

  test "should delete unused customer" do
    # Create a new customer that hasn't been used
    unused_customer = Customer.create!(
      matchcode: "UNUSED",
      name: "Unused Customer",
      vat_id: "EU191919191",
      sales_tax_customer_class: @customer.sales_tax_customer_class,
      team: teams(:default)
    )

    assert_difference("Customer.count", -1) do
      delete customer_url(unused_customer)
    end
    assert_redirected_to customers_url
    follow_redirect!
    assert_select ".alert-success", text: /successfully deleted/
  end

  test "should not delete customer used in invoices" do
    # Use the good_eu customer which has invoices
    used_customer = customers(:good_eu)

    # Ensure it has invoices
    assert used_customer.used_in_invoices?, "Customer should have invoices for this test"

    assert_no_difference("Customer.count") do
      delete customer_url(used_customer)
    end
    assert_redirected_to customers_url
    follow_redirect!
    assert_select ".alert-danger", text: /Cannot delete customer that has been used in invoices/
  end

  test "customer deletion prevention logic works" do
    # Test that unused customer can be deleted
    unused_customer = Customer.create!(
      matchcode: "UNUSED2",
      name: "Another Unused Customer",
      vat_id: "EU202020202",
      sales_tax_customer_class: @customer.sales_tax_customer_class,
      team: teams(:default)
    )
    assert_not unused_customer.used_in_invoices?

    # Test that used customer cannot be deleted
    used_customer = customers(:good_eu)
    assert used_customer.used_in_invoices?
  end

  test "should filter customers by active status and handle index properly" do
    # Create inactive customer
    Customer.create!(
      matchcode: "INACTIVE",
      name: "Inactive Customer",
      vat_id: "EU212121212",
      active: false,
      sales_tax_customer_class: @customer.sales_tax_customer_class,
      team: teams(:default)
    )

    # Test all filter options in a single request cycle
    [ "active", "inactive", "all" ].each do |filter_type|
      get customers_url(filter: filter_type)
      assert_response :success
      assert_select ".status-filter .active", text: filter_type.capitalize

      case filter_type
      when "active"
        assert_select "td", text: "INACTIVE", count: 0
      when "inactive", "all"
        assert_select "td", text: "INACTIVE"
      end
    end

    # Test default behavior (should default to active)
    get customers_url
    assert_response :success
    assert_select ".status-filter .active", text: "Active"
    assert_select "td", text: "INACTIVE", count: 0
  end

  test "active customer shows no inactive badge on show page" do
    get customer_url(@customer)
    assert_response :success
    assert_select "nav[aria-label='breadcrumb'] .badge", count: 0
    assert_select ".badge", text: "Inactive", count: 0
  end

  test "inactive customer shows inactive badge on show page" do
    @customer.update!(active: false)
    get customer_url(@customer)
    assert_response :success
    assert_select ".badge.bg-secondary", text: "Inactive"
  end

  test "should allow updating customer active status" do
    patch customer_url(@customer), params: {
      customer: { active: false }
    }
    assert_redirected_to customer_url(@customer)

    @customer.reload
    assert_not @customer.active?
  end

  test "should persist supplier_number through the form" do
    patch customer_url(@customer), params: {
      customer: { supplier_number: "SUP-42" }
    }
    assert_redirected_to customer_url(@customer)
    assert_equal "SUP-42", @customer.reload.supplier_number
  end

  test "show page links to invoices and delivery notes filtered to this customer across all years" do
    get customer_url(@customer)
    assert_response :success
    assert_select "a[href=?][data-turbo-prefetch=?]", invoices_path(customer_id: @customer.id, year: "all"), "false", text: /Invoices/
    assert_select "a[href=?][data-turbo-prefetch=?]", delivery_notes_path(customer_id: @customer.id, year: "all"), "false", text: /Delivery Notes/
  end

  test "show page renders supplier number row only when set" do
    @customer.update!(supplier_number: nil)
    get customer_url(@customer)
    assert_response :success
    assert_select "strong", text: "Supplier No.:", count: 0

    @customer.update!(supplier_number: "SUP-99")
    get customer_url(@customer)
    assert_response :success
    assert_select "strong", text: "Supplier No.:"
    assert_select ".col-sm-8", text: /SUP-99/
  end
end
