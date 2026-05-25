require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  def build_customer(**overrides)
    Customer.new({
      matchcode: "TEST",
      name: "Test Customer",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      active: true
    }.merge(overrides))
  end

  def create_customer(**overrides)
    build_customer(**overrides).tap(&:save!)
  end

  test "requires matchcode" do
    customer = build_customer(matchcode: nil)
    assert_not customer.valid?
    assert_includes customer.errors[:matchcode], "can't be blank"
  end

  test "requires name" do
    customer = build_customer(name: nil)
    assert_not customer.valid?
    assert_includes customer.errors[:name], "can't be blank"
  end

  test "set_default_language assigns English on create when language is not set" do
    customer = build_customer(language: nil)
    customer.valid?
    assert_equal languages(:english), customer.language
  end

  test "set_default_language does not override an explicitly set language" do
    customer = build_customer(language: languages(:german))
    customer.valid?
    assert_equal languages(:german), customer.language
  end

  test "set_default_language only runs on create" do
    customer = create_customer(language: nil)
    customer.language = nil
    customer.valid?
    assert_nil customer.language
  end

  test "used_in_invoices? is true for a customer with invoices" do
    assert customers(:good_eu).used_in_invoices?
  end

  test "used_in_invoices? is false for a customer without invoices" do
    assert_not create_customer.used_in_invoices?
  end

  test "before_destroy rejects destroy when invoices reference the customer" do
    customer = customers(:good_eu)
    assert_not customer.destroy
    assert_includes customer.errors[:base], "Cannot delete customer that has been used in invoices"
  end

  test "destroy succeeds when no invoices reference the customer" do
    assert create_customer.destroy
  end

  test "active scope returns only active customers" do
    inactive = create_customer(active: false)
    assert_includes Customer.active, customers(:good_eu)
    assert_not_includes Customer.active, inactive
  end

  test "inactive scope returns only inactive customers" do
    inactive = create_customer(active: false)
    assert_includes Customer.inactive, inactive
    assert_not_includes Customer.inactive, customers(:good_eu)
  end
end
