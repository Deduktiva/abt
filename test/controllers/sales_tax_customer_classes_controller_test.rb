require "test_helper"

class SalesTaxCustomerClassesControllerTest < ActionDispatch::IntegrationTest
  test "destroy removes a customer class that has no rates or customers" do
    customer_class = SalesTaxCustomerClass.create!(name: "Unused", invoice_note: "")

    assert_difference("SalesTaxCustomerClass.count", -1) do
      delete sales_tax_customer_class_url(customer_class)
    end
    assert_redirected_to sales_tax_customer_classes_url
  end

  test "destroy reports an error instead of raising when rates reference the customer class" do
    customer_class = sales_tax_customer_classes(:national)

    assert_no_difference("SalesTaxCustomerClass.count") do
      delete sales_tax_customer_class_url(customer_class)
    end
    assert_redirected_to sales_tax_customer_classes_url
    assert_match(/sales tax rates/i, flash[:alert])
  end
end
