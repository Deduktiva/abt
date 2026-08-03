require "application_system_test_case"

class SearchableDropdownTest < ApplicationSystemTestCase
  MARKUP_NAME = '<img src=x class="xss-probe">'.freeze

  setup do
    @invoice = invoices(:draft_invoice)
  end

  test "pre-selected customer name renders as text, not markup" do
    @invoice.customer.update_column(:name, MARKUP_NAME)
    visit "/invoices/#{@invoice.id}/edit"

    # The subtext span appears only once the controller has re-rendered the
    # display from the loaded options.
    assert_selector ".customer-dropdown .select-display .small span", wait: 10
    assert_no_selector ".customer-dropdown img.xss-probe", visible: :all
    assert_selector ".customer-dropdown .select-display .fw-normal", text: MARKUP_NAME
  end

  test "customer name picked from the option list renders as text, not markup" do
    customer = customers(:good_eu)
    customer.update_column(:name, MARKUP_NAME)
    visit "/invoices/#{@invoice.id}/edit"

    within ".customer-dropdown" do
      find("[data-searchable-dropdown-target='select']").click
      find(".searchable-option[data-item-id='#{customer.id}']", wait: 10).click
    end

    assert_selector ".customer-dropdown .select-display .fw-normal", text: MARKUP_NAME
    assert_no_selector ".customer-dropdown img.xss-probe", visible: :all
  end
end
