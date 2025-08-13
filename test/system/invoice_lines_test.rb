require "test_helper"

class InvoiceLinesTest < ActionDispatch::SystemTestCase
  setup do
    @customer = customers(:good_eu)
    @project = projects(:one)
    @invoice = invoices(:draft_invoice)
  end

  test "adding new lines to invoice" do
    visit edit_invoice_path(@invoice)

    # Count initial lines
    initial_line_count = all('[data-line-index]').count

    # Click Add Line button
    click_button "Add Line"

    # Verify new line was added
    assert_selector '[data-line-index]', count: initial_line_count + 1

    # Check that the new line has the correct position
    new_line = all('[data-line-index]').last
    position_field = new_line.find('input[name*="[position]"]', visible: false)
    assert_equal (initial_line_count + 1).to_s, position_field.value

    # Verify new line has default type 'item'
    type_select = new_line.find('select[name*="[type]"]')
    assert_equal 'item', type_select.value

    # Verify item-specific fields are visible
    within new_line do
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: true
      assert_selector 'input[name*="[quantity]"]'
      assert_selector 'input[name*="[rate]"]'
    end
  end

  test "removing lines from invoice" do
    visit edit_invoice_path(@invoice)

    initial_line_count = all('[data-line-index]').count

    # Find first line's remove button and click it
    first_line = first('[data-line-index]')
    within first_line do
      click_button "Remove"
    end

    # If it's a persisted record, it should be hidden
    # If it's new, it should be removed from DOM
    id_field = first_line.find('input[name*="[id]"]', visible: false)
    if id_field.value.present?
      # Persisted record - should be hidden
      assert_not first_line.visible?
      destroy_field = first_line.find('input[name*="[_destroy]"]', visible: false)
      assert_equal '1', destroy_field.value
    else
      # New record - should be removed from DOM
      assert_selector '[data-line-index]', count: initial_line_count - 1
    end
  end

  test "moving lines up and down" do
    visit edit_invoice_path(@invoice)

    lines = all('[data-line-index]')
    return if lines.count < 2 # Need at least 2 lines for this test

    first_line = lines[0]
    second_line = lines[1]

    # Get initial positions
    first_position = first_line.find('input[name*="[position]"]', visible: false).value
    second_position = second_line.find('input[name*="[position]"]', visible: false).value

    # Move second line up
    within second_line do
      click_button "↑"
    end

    # Wait for DOM to update
    sleep 0.1

    # Verify positions have swapped
    updated_lines = all('[data-line-index]')
    new_first = updated_lines[0]
    new_second = updated_lines[1]

    new_first_position = new_first.find('input[name*="[position]"]', visible: false).value
    new_second_position = new_second.find('input[name*="[position]"]', visible: false).value

    assert_equal second_position, new_first_position
    assert_equal first_position, new_second_position
  end

  test "field visibility changes when switching line types" do
    visit edit_invoice_path(@invoice)

    # Add a new line
    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      type_select = find('select[name*="[type]"]')

      # Start with 'item' type (default)
      assert_equal 'item', type_select.value
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: true
      assert_selector '[data-line-type-target="notSubheading"]', visible: true

      # Change to 'subheading'
      select 'Subheading', from: type_select[:name]
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: false
      assert_selector '[data-line-type-target="notSubheading"]', visible: false

      # Change to 'text'
      select 'Text', from: type_select[:name]
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: false
      assert_selector '[data-line-type-target="notSubheading"]', visible: true
    end
  end

  test "total calculation updates when adding and modifying lines" do
    visit edit_invoice_path(@invoice)

    # Find total display
    total_element = find('[data-invoice-lines-target="total"]')
    initial_total = total_element.text

    # Add new line
    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      # Set quantity and rate
      fill_in find('input[name*="[quantity]"]')[:name], with: '2'
      fill_in find('input[name*="[rate]"]')[:name], with: '10.50'

      # Trigger change event
      find('input[name*="[rate]"]').native.send_keys(:tab)
    end

    # Wait for calculation
    sleep 0.1

    # Verify total has updated
    updated_total = total_element.text
    assert_not_equal initial_total, updated_total

    # Verify line total shows €21.00 (2 × 10.50)
    line_total = new_line.find('[data-line-total]').text
    assert_equal '€21.00', line_total
  end

  test "product dropdown functionality" do
    # Create a test product
    product = Product.create!(
      title: "Test Product",
      description: "Test Description",
      rate: 15.00,
      sales_tax_product_class: sales_tax_product_classes(:one)
    )

    visit edit_invoice_path(@invoice)

    # Add new line
    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      # Click product dropdown button
      click_button "…"

      # Verify dropdown is visible
      assert_selector '[data-product-dropdown]', visible: true

      # Select the product
      select product.title, from: find('[data-product-select]')[:name]

      # Use the selected product
      click_button "Use"

      # Verify fields are populated
      assert_equal 'item', find('select[name*="[type]"]').value
      assert_equal product.title, find('input[name*="[title]"]').value
      assert_equal product.description, find('textarea[name*="[description]"]').value
      assert_equal product.rate.to_s, find('input[name*="[rate]"]').value
    end
  end

  test "error styling is cleared when user interacts with fields" do
    # Create an invoice with validation errors
    invalid_invoice = Invoice.create(customer: nil) # This will have errors

    visit edit_invoice_path(@invoice)

    # Add new line
    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      title_field = find('input[name*="[title]"]')

      # Simulate error styling (would normally come from server validation)
      page.execute_script("arguments[0].closest('.form-group').classList.add('field_with_errors')", title_field)

      # Verify error styling exists
      assert_selector '.field_with_errors'

      # Type in the field
      title_field.fill_in with: 'New Title'

      # Wait for JavaScript to process
      sleep 0.1

      # Verify error styling is removed
      assert_no_selector '.field_with_errors'
    end
  end
end
