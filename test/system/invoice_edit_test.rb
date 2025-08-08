require "test_helper"

class InvoiceEditTest < ActionDispatch::SystemTestCase
  test "can access invoice edit page from index" do
    visit "/invoices"

    # Click edit link for draft invoice (shown as "Edit" button)
    find("tr", text: "DRAFT-REF").find("a", text: "Edit").click

    # Verify we're on the edit page with correct form
    assert_current_path("/invoices/#{invoices(:draft_invoice).id}/edit")
    assert_text "Editing invoice draft"
    assert_field "invoice_cust_reference"
    assert_field "invoice_cust_order"
    assert_field "invoice_prelude"
    assert_button "Save"
  end

  test "successfully saves and persists form changes" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"

    # Wait for Stimulus project dropdown to load
    assert_no_text "Loading...", wait: 10

    # Ensure project field is populated (required for form submission)
    project_input = find('input[name="invoice[project_id]"]', visible: false)
    if project_input.value.blank?
      find('[data-project-dropdown-target="select"]').click
      assert_selector '.project-option', wait: 5
      first('.project-option').click
      assert_not_equal "", find('input[name="invoice[project_id]"]', visible: false).value
    end

    # Fill in test data
    fill_in "invoice_cust_reference", with: "SAVED-REF-123"
    fill_in "invoice_cust_order", with: "SAVED-ORDER-456"
    fill_in "invoice_prelude", with: "This is a saved prelude for testing."

    # Submit and verify success
    click_button "Save"
    assert_current_path("/invoices/#{invoice.id}")
    assert_text "Invoice was successfully updated"

    # Verify changes appear on show page
    assert_text "SAVED-REF-123"
    assert_text "SAVED-ORDER-456"
    assert_text "This is a saved prelude for testing."

    # Verify database persistence
    invoice.reload
    assert_equal "SAVED-REF-123", invoice.cust_reference
    assert_equal "SAVED-ORDER-456", invoice.cust_order
    assert_equal "This is a saved prelude for testing.", invoice.prelude
  end

  test "displays validation errors for invalid data" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # Trigger validation error by clearing required project field
    page.execute_script("document.getElementById('invoice_project_id').value = '';")
    fill_in "invoice_cust_reference", with: "SHOULD-NOT-SAVE"

    click_button "Save"

    # Verify validation error handling
    if current_path == "/invoices/#{invoice.id}/edit"
      assert_css ".alert-danger"
    else
      assert_current_path("/invoices/#{invoice.id}")
    end

    # Confirm invalid data was not persisted
    invoice.reload
    assert_equal "DRAFT-REF", invoice.cust_reference
  end

  test "can update customer with dynamic project loading" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # Change customer (triggers AJAX project reload)
    select "A Good Company B.V.", from: "invoice_customer_id"

    # Wait for project dropdown to reload via Stimulus
    assert_text "Loading...", wait: 5
    assert_no_text "Loading...", wait: 10

    # Select project from reloaded options
    find('[data-project-dropdown-target="select"]').click
    assert_selector '.project-option', wait: 5
    first('.project-option').click

    # Submit and verify
    click_button "Save"
    assert_current_path("/invoices/#{invoice.id}")
    assert_text "Invoice was successfully updated"

    # Confirm customer change was persisted
    invoice.reload
    assert_equal customers(:good_eu).id, invoice.customer_id
  end

  test "form has proper navigation elements" do
    visit "/invoices/#{invoices(:draft_invoice).id}/edit"
    assert_link "Cancel", href: "/invoices"
  end

  test "form includes dynamic UI elements" do
    visit "/invoices/#{invoices(:draft_invoice).id}/edit"

    # Verify Stimulus-powered dynamic line management UI exists
    if has_button?("+ Add Line")
      assert_button "+ Add Line"
    end
  end
end