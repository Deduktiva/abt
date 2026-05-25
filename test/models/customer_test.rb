require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  def fresh_customer(**overrides)
    Customer.new({
      matchcode: "FRESH",
      name: "Fresh Customer",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      active: true
    }.merge(overrides))
  end

  test "requires matchcode" do
    customer = fresh_customer(matchcode: nil)
    assert_not customer.valid?
    assert_includes customer.errors[:matchcode], "can't be blank"
  end

  test "requires name" do
    customer = fresh_customer(name: nil)
    assert_not customer.valid?
    assert_includes customer.errors[:name], "can't be blank"
  end

  test "set_default_language assigns English on create when language is not set" do
    customer = fresh_customer(language: nil)
    customer.valid?
    assert_equal languages(:english), customer.language
  end

  test "set_default_language does not override an explicitly set language" do
    customer = fresh_customer(language: languages(:german))
    customer.valid?
    assert_equal languages(:german), customer.language
  end

  test "set_default_language only runs on create" do
    customer = Customer.create!(
      matchcode: "DEFAULT_LANG",
      name: "Default Language Customer",
      sales_tax_customer_class: sales_tax_customer_classes(:eu)
    )
    customer.language = nil
    customer.valid?
    assert_nil customer.language
  end

  test "used_in_invoices? is true for a customer with invoices" do
    assert customers(:good_eu).used_in_invoices?
  end

  test "used_in_invoices? is false for a customer without invoices" do
    customer = Customer.create!(
      matchcode: "UNUSED",
      name: "Unused Customer",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english)
    )
    assert_not customer.used_in_invoices?
  end

  test "before_destroy rejects destroy when invoices reference the customer" do
    customer = customers(:good_eu)
    assert_not customer.destroy
    assert_includes customer.errors[:base], "Cannot delete customer that has been used in invoices"
  end

  test "destroy succeeds when no invoices reference the customer" do
    customer = Customer.create!(
      matchcode: "UNUSED",
      name: "Unused Customer",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english)
    )
    assert customer.destroy
  end

  test "active scope returns only active customers" do
    inactive = Customer.create!(
      matchcode: "INACTIVE",
      name: "Inactive Customer",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      active: false
    )
    assert_includes Customer.active, customers(:good_eu)
    assert_not_includes Customer.active, inactive
  end

  test "inactive scope returns only inactive customers" do
    inactive = Customer.create!(
      matchcode: "INACTIVE",
      name: "Inactive Customer",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      active: false
    )
    assert_includes Customer.inactive, inactive
    assert_not_includes Customer.inactive, customers(:good_eu)
  end
end
