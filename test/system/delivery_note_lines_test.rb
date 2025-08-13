require "test_helper"

class DeliveryNoteLinesTest < ActionDispatch::SystemTestCase
  setup do
    @customer = customers(:good_eu)
    @project = projects(:one)
    @delivery_note = delivery_notes(:draft_delivery_note)
  end

  test "adding new lines to delivery note" do
    visit edit_delivery_note_path(@delivery_note)

    # Count initial lines
    initial_line_count = all('[data-line-index]').count

    # Click Add Line button
    click_button "Add Line"

    # Wait for the new line to be added
    assert_selector '[data-line-index]', count: initial_line_count + 1, wait: 2

    # Check that the new line has the correct position
    new_line = all('[data-line-index]').last
    position_field = new_line.find('input[name*="[position]"]', visible: false)
    assert_equal (initial_line_count + 1).to_s, position_field.value

    # Verify new line has default type 'item'
    type_select = new_line.find('select[name*="[type]"]')
    assert_equal 'item', type_select.value

    # Verify item-specific fields are visible (quantity for delivery notes)
    within new_line do
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: true
      assert_selector 'input[name*="[quantity]"]'
      # Delivery notes don't have rate fields like invoices
      assert_no_selector 'input[name*="[rate]"]'
    end
  end

  test "removing lines from delivery note" do
    visit edit_delivery_note_path(@delivery_note)

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
    visit edit_delivery_note_path(@delivery_note)

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
    visit edit_delivery_note_path(@delivery_note)

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

  test "quantity field is required for item type lines" do
    visit edit_delivery_note_path(@delivery_note)

    # Add new line
    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      # Ensure it's an item type
      type_select = find('select[name*="[type]"]')
      select 'Item', from: type_select[:name] if type_select.value != 'item'

      # Verify quantity field is visible and required for items
      quantity_field = find('input[name*="[quantity]"]')
      assert quantity_field.visible?

      # Fill in other required fields
      fill_in find('input[name*="[title]"]')[:name], with: 'Test Item'

      # Leave quantity empty and verify validation
      quantity_field.set('')
    end

    # Try to save the form
    click_button "Update Delivery note"

    # Should stay on edit page due to validation error
    assert_current_path edit_delivery_note_path(@delivery_note)
  end

  test "textarea auto-resize functionality" do
    visit edit_delivery_note_path(@delivery_note)

    # Add new line
    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      description_field = find('textarea[name*="[description]"]')

      # Get initial height
      initial_height = description_field.native.size.height

      # Add multiple lines of text
      long_text = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
      description_field.fill_in with: long_text

      # Trigger input event to activate auto-resize
      page.execute_script("arguments[0].dispatchEvent(new Event('input'))", description_field)

      # Wait for resize
      sleep 0.1

      # Verify height has increased
      new_height = description_field.native.size.height
      assert new_height > initial_height, "Textarea should have auto-resized"
    end
  end

  test "error styling is cleared when user interacts with fields" do
    visit edit_delivery_note_path(@delivery_note)

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

  test "type field error styling is cleared when changed" do
    visit edit_delivery_note_path(@delivery_note)

    # Add new line
    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      type_select = find('select[name*="[type]"]')

      # Simulate error styling
      page.execute_script("arguments[0].closest('.form-group').classList.add('field_with_errors')", type_select)

      # Verify error styling exists
      assert_selector '.field_with_errors'

      # Change type selection
      select 'Text', from: type_select[:name]

      # Wait for JavaScript to process
      sleep 0.1

      # Verify error styling is removed
      assert_no_selector '.field_with_errors'
    end
  end

  test "delivery note specific line types work correctly" do
    visit edit_delivery_note_path(@delivery_note)

    # Add new line
    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      type_select = find('select[name*="[type]"]')

      # Test all delivery note line types
      ['Text', 'Item', 'Subheading', 'Plaintext'].each do |line_type|
        select line_type, from: type_select[:name]

        # Verify the selection took effect
        assert_equal line_type.downcase, type_select.value

        # Verify appropriate fields are shown/hidden
        case line_type.downcase
        when 'subheading'
          assert_selector 'div[data-line-type-target="itemOnly"]', visible: false
          assert_selector '[data-line-type-target="notSubheading"]', visible: false
        when 'item'
          assert_selector 'div[data-line-type-target="itemOnly"]', visible: true
          assert_selector '[data-line-type-target="notSubheading"]', visible: true
          assert_selector 'input[name*="[quantity]"]'
        else # text, plaintext
          assert_selector 'div[data-line-type-target="itemOnly"]', visible: false
          assert_selector '[data-line-type-target="notSubheading"]', visible: true
        end
      end
    end
  end
end
