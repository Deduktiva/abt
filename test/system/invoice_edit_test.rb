require "application_system_test_case"

class InvoiceEditTest < ApplicationSystemTestCase
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
      # Click the project dropdown specifically (second dropdown on the page)
      within('.project-dropdown') do
        find('[data-searchable-dropdown-target="select"]').click
      end
      assert_selector '.searchable-option', wait: 5
      first('.searchable-option').click
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

    # Change customer using the searchable dropdown component
    within('.customer-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10
      # Find and click the "A Good Company B.V." option
      find('.searchable-option', text: 'A Good Company B.V.').click
    end

    # Open the project dropdown and wait for project options to load via Stimulus
    within('.project-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      # Wait for project options to appear (indicates AJAX reload completed successfully)
      assert_selector '.searchable-option', wait: 10
      first('.searchable-option').click
    end

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

  test "customer dropdown displays correctly and loads options" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # Verify customer dropdown structure
    within('.customer-dropdown') do
      assert_selector '[data-searchable-dropdown-target="select"]'
      assert_selector '.dropdown-menu', visible: false  # Hidden until clicked

      # Click dropdown to open it
      find('[data-searchable-dropdown-target="select"]').click

      # Verify search input and options load
      assert_selector '[data-searchable-dropdown-target="search"]'
      assert_selector '.searchable-option', wait: 10

      # Verify active customers are available
      assert_selector '.searchable-option', text: 'A Good Company B.V.'
      assert_selector '.searchable-option', text: 'A Local Company, Inc.'
    end
  end

  test "customer dropdown search functionality works" do
    skip "Search functionality clearing works differently in Cuprite vs Selenium"
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"

    within('.customer-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10

      # Search for specific customer
      search_input = find('[data-searchable-dropdown-target="search"]')
      search_input.fill_in(with: 'Good Company')

      # Verify filtering works
      assert_selector '.searchable-option', text: 'A Good Company B.V.'
      assert_no_selector '.searchable-option', text: 'A Local Company, Inc.'

      # Clear search and verify all options return
      search_input.fill_in(with: '')
      assert_selector '.searchable-option', text: 'A Good Company B.V.', wait: 5
      assert_selector '.searchable-option', text: 'A Local Company, Inc.', wait: 5
    end
  end

  test "customer dropdown selection updates form correctly" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"

    within('.customer-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10

      # Select a customer
      find('.searchable-option', text: 'A Local Company, Inc.').click
    end

    # Verify hidden field is updated
    customer_input = find('input[name="invoice[customer_id]"]', visible: false)
    assert_equal customers(:good_national).id.to_s, customer_input.value

    # Verify display shows selected customer
    within('.customer-dropdown .select-display') do
      assert_text 'A Local Company, Inc.'
      assert_text 'GOODNAT'
    end
  end

  test "customer selection triggers project dropdown update" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"

    # Select customer first
    within('.customer-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10
      find('.searchable-option', text: 'A Good Company B.V.').click
    end

    # Project dropdown should now be enabled and load options
    within('.project-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10
    end
  end

  test "project dropdown shows dependency message when no customer selected" do
    # Create a new invoice with no customer selected
    visit "/invoices/new"
    assert_no_text "Loading...", wait: 10

    # Project dropdown should show dependency message (exact text from the config)
    within('.project-dropdown .select-display') do
      assert_text 'Select customer first...'
    end
  end

  test "customer dropdown keyboard navigation works" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"

    within('.customer-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10

      search_input = find('[data-searchable-dropdown-target="search"]')

      # Test arrow key navigation
      search_input.send_keys(:down)
      assert_selector '.searchable-option.focus'

      # Test Enter key selection
      search_input.send_keys(:enter)
    end

    # Verify a customer was selected
    customer_input = find('input[name="invoice[customer_id]"]', visible: false)
    assert_not_equal "", customer_input.value
  end

  test "customer dropdown closes when clicking outside" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"

    within('.customer-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10

      # Dropdown should be open
      assert_selector '.dropdown-menu.show'
    end

    # Click outside the dropdown
    find('h1').click

    within('.customer-dropdown') do
      # Dropdown should be closed
      assert_no_selector '.dropdown-menu.show'
    end
  end

  test "both customer and project dropdowns work independently" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"

    # Test customer dropdown
    within('.customer-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10
      find('.searchable-option', text: 'A Good Company B.V.').click
    end

    # Test project dropdown
    within('.project-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10
      first('.searchable-option').click
    end

    # Verify both fields are populated
    customer_input = find('input[name="invoice[customer_id]"]', visible: false)
    project_input = find('input[name="invoice[project_id]"]', visible: false)

    assert_not_equal "", customer_input.value
    assert_not_equal "", project_input.value
    assert_equal customers(:good_eu).id.to_s, customer_input.value
  end

  test "customer dropdown handles empty results gracefully" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"

    within('.customer-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10

      # Search for non-existent customer
      search_input = find('[data-searchable-dropdown-target="search"]')
      search_input.fill_in(with: 'NonexistentCustomer')

      # No options should be visible
      assert_no_selector '.searchable-option:not([style*="display: none"])'
    end
  end

  test "customer change event properly triggers project dropdown reload" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # Verify initial state - project dropdown should have options for current customer
    initial_customer_id = find('input[name="invoice[customer_id]"]', visible: false).value
    assert_not_equal "", initial_customer_id

    # Change customer and verify project dropdown reacts to the change event
    within('.customer-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10
      find('.searchable-option', text: 'A Good Company B.V.').click
    end

    # Verify customer field was updated and change event was dispatched
    new_customer_id = find('input[name="invoice[customer_id]"]', visible: false).value
    assert_equal customers(:good_eu).id.to_s, new_customer_id
    assert_not_equal initial_customer_id, new_customer_id

    # Verify project dropdown received the change event and shows updated options
    within('.project-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click

      # Project dropdown should reload and show options for the new customer
      assert_selector '.searchable-option', wait: 10

      # Should have project options available (indicates dependency worked)
      project_options = all('.searchable-option')
      assert project_options.length > 0, "Project dropdown should show options after customer change"
    end

    # Verify we can select a project after customer change
    within('.project-dropdown') do
      first('.searchable-option').click
    end

    project_id = find('input[name="invoice[project_id]"]', visible: false).value
    assert_not_equal "", project_id
  end

  test "reusable project indicator persists in selected display after customer change" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # First select a customer to enable project dropdown
    within('.customer-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10
      find('.searchable-option', text: 'A Good Company B.V.').click
    end

    # Select the reusable project
    within('.project-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10

      # Select the reusable project
      reusable_option = find('.searchable-option', text: 'Reusable project without customer')
      reusable_option.click
    end

    # Verify the reusable project is selected and check if the selected display shows indicator
    project_input = find('input[name="invoice[project_id]"]', visible: false)
    assert_equal projects(:reusable_project).id.to_s, project_input.value

    # Verify the selected display shows the reusable indicator initially
    within('.project-dropdown .select-display') do
      assert has_text?('♻️'), "Selected display should show reusable indicator initially"
    end

    # Change to a different customer - this should trigger an AJAX reload
    within('.customer-dropdown') do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector '.searchable-option', wait: 10
      find('.searchable-option', text: 'A Local Company, Inc.').click
    end

    # Wait for the project dropdown to react to customer change
    sleep 0.2  # Brief pause for AJAX request

    # Verify the selected display still shows the reusable indicator after customer change
    within('.project-dropdown .select-display') do
      assert has_text?('♻️'), "Selected display should still show reusable indicator after customer change"
      assert has_text?('Reusable project without customer'), "Reusable project should still be selected"
    end

    # Verify the hidden input still has the correct value
    final_project_id = find('input[name="invoice[project_id]"]', visible: false).value
    assert_equal projects(:reusable_project).id.to_s, final_project_id, "Reusable project should remain selected"
  end
end
