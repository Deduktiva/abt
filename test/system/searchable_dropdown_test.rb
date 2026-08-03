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

  test "denied option request reports the failure instead of loading forever" do
    group_permissions(:admin_projects_view).destroy!
    visit "/invoices/#{@invoice.id}/edit"

    within ".project-dropdown" do
      find("[data-searchable-dropdown-target='select']").click
      assert_selector ".dropdown-content", text: "Could not load projects", wait: 10
    end

    find("[data-controller='error-notification'] .nav-link").click
    assert_selector ".error-notification-error-message",
                    text: "Failed to load projects: not signed in or not permitted"
  end

  test "rapid customer switches leave a usable project list" do
    visit "/invoices/#{@invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    switch_customer_twice(customers(:good_eu), customers(:good_national))

    within ".project-dropdown" do
      find("[data-searchable-dropdown-target='select']").click
      find(".searchable-option[data-item-id='#{projects(:reusable_project).id}']", wait: 10).click
    end

    assert_equal projects(:reusable_project).id.to_s,
                 find("#invoice_project_id", visible: false).value
  end

  private

  def switch_customer_twice(first, second)
    page.execute_script(<<~JS)
      const field = document.querySelector('#invoice_customer_id')
      field.value = '#{first.id}'
      field.dispatchEvent(new Event('change', { bubbles: true }))
      field.value = '#{second.id}'
      field.dispatchEvent(new Event('change', { bubbles: true }))
    JS
  end
end
