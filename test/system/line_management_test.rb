require "test_helper"

class LineManagementTest < ActionDispatch::SystemTestCase
  setup do
    @invoice = invoices(:draft_invoice)
    @delivery_note = delivery_notes(:draft_delivery_note)

    # Add test lines to work with
    @invoice.invoice_lines.create!(
      type: 'item', title: 'First Item', position: 1,
      quantity: 1, rate: 10.0, amount: 10.0
    )
    @invoice.invoice_lines.create!(
      type: 'text', title: 'Second Text', position: 2, amount: 0
    )

    @delivery_note.delivery_note_lines.create!(
      type: 'item', title: 'First Delivery', position: 1, quantity: 5
    )
    @delivery_note.delivery_note_lines.create!(
      type: 'text', title: 'Second Note', position: 2
    )
  end

  # Test removing persisted lines
  test "removing persisted invoice lines marks them for destruction" do
    visit edit_invoice_path(@invoice)

    first_line = first('[data-line-index]')
    within first_line do
      click_button "🗑"
    end

    # Persisted line should be hidden, not removed
    assert_not first_line.visible?
    destroy_field = first_line.find('input[name*="[_destroy]"]', visible: false)
    assert_equal '1', destroy_field.value
  end

  test "removing persisted delivery note lines marks them for destruction" do
    visit edit_delivery_note_path(@delivery_note)

    first_line = first('[data-line-index]')
    within first_line do
      click_button "🗑"
    end

    assert_not first_line.visible?
    destroy_field = first_line.find('input[name*="[_destroy]"]', visible: false)
    assert_equal '1', destroy_field.value
  end

  # Test removing new lines
  test "removing new invoice lines removes them from DOM" do
    visit edit_invoice_path(@invoice)

    initial_count = all('[data-line-index]').count
    click_button "Add Line"
    assert_selector '[data-line-index]', count: initial_count + 1

    # Remove the new line
    new_line = all('[data-line-index]').last
    within new_line do
      click_button "🗑"
    end

    # New line should be completely removed from DOM
    assert_selector '[data-line-index]', count: initial_count
  end

  test "removing new delivery note lines removes them from DOM" do
    visit edit_delivery_note_path(@delivery_note)

    initial_count = all('[data-line-index]').count
    click_button "Add Line"
    assert_selector '[data-line-index]', count: initial_count + 1

    new_line = all('[data-line-index]').last
    within new_line do
      click_button "🗑"
    end

    assert_selector '[data-line-index]', count: initial_count
  end

  # Test line reordering
  test "moving invoice lines up reorders them correctly" do
    visit edit_invoice_path(@invoice)

    lines = all('[data-line-index]')
    first_title = lines[0].find('input[name*="[title]"]').value
    second_title = lines[1].find('input[name*="[title]"]').value

    # Move second line up
    within lines[1] do
      click_button "▲"
    end

    sleep 0.1

    updated_lines = all('[data-line-index]')
    new_first_title = updated_lines[0].find('input[name*="[title]"]').value
    new_second_title = updated_lines[1].find('input[name*="[title]"]').value

    assert_equal second_title, new_first_title
    assert_equal first_title, new_second_title

    # Verify positions are updated
    assert_equal '1', updated_lines[0].find('input[name*="[position]"]', visible: false).value
    assert_equal '2', updated_lines[1].find('input[name*="[position]"]', visible: false).value
  end

  test "moving invoice lines down reorders them correctly" do
    visit edit_invoice_path(@invoice)

    lines = all('[data-line-index]')
    first_title = lines[0].find('input[name*="[title]"]').value
    second_title = lines[1].find('input[name*="[title]"]').value

    # Move first line down
    within lines[0] do
      click_button "▼"
    end

    sleep 0.1

    updated_lines = all('[data-line-index]')
    new_first_title = updated_lines[0].find('input[name*="[title]"]').value
    new_second_title = updated_lines[1].find('input[name*="[title]"]').value

    assert_equal second_title, new_first_title
    assert_equal first_title, new_second_title
  end

  test "moving delivery note lines up reorders them correctly" do
    visit edit_delivery_note_path(@delivery_note)

    lines = all('[data-line-index]')
    first_title = lines[0].find('input[name*="[title]"]').value
    second_title = lines[1].find('input[name*="[title]"]').value

    within lines[1] do
      click_button "▲"
    end

    sleep 0.1

    updated_lines = all('[data-line-index]')
    new_first_title = updated_lines[0].find('input[name*="[title]"]').value
    new_second_title = updated_lines[1].find('input[name*="[title]"]').value

    assert_equal second_title, new_first_title
    assert_equal first_title, new_second_title
  end

  # Test form field reindexing
  test "form field names are reindexed after reordering invoice lines" do
    visit edit_invoice_path(@invoice)

    lines = all('[data-line-index]')

    # Move second line up
    within lines[1] do
      click_button "▲"
    end

    sleep 0.1

    # Check that field names have been reindexed correctly
    updated_lines = all('[data-line-index]')
    first_field_name = updated_lines[0].find('input[name*="[title]"]')[:name]
    second_field_name = updated_lines[1].find('input[name*="[title]"]')[:name]

    # The reindexing uses 0-based indexing in the field names
    assert first_field_name.match?(/\[\d+\]/), "First line should have numeric index"
    assert second_field_name.match?(/\[\d+\]/), "Second line should have numeric index"

    # More importantly, they should be different (indicating reindexing occurred)
    assert_not_equal first_field_name, second_field_name, "Field names should be different after reordering"
  end

  test "form field names are reindexed after reordering delivery note lines" do
    visit edit_delivery_note_path(@delivery_note)

    lines = all('[data-line-index]')

    within lines[1] do
      click_button "▲"
    end

    sleep 0.1

    updated_lines = all('[data-line-index]')
    first_field_name = updated_lines[0].find('input[name*="[title]"]')[:name]
    second_field_name = updated_lines[1].find('input[name*="[title]"]')[:name]

    assert first_field_name.match?(/\[\d+\]/), "First line should have numeric index"
    assert second_field_name.match?(/\[\d+\]/), "Second line should have numeric index"
    assert_not_equal first_field_name, second_field_name, "Field names should be different after reordering"
  end

  # Test error handling and field interactions
  test "error styling is cleared when typing in invoice line fields" do
    visit edit_invoice_path(@invoice)

    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      title_field = find('input[name*="[title]"]')

      # Add error styling
      page.execute_script("arguments[0].closest('div').classList.add('field_with_errors')", title_field)
      assert_selector '.field_with_errors'

      # Type in field should clear error
      title_field.fill_in with: 'New Title'
      sleep 0.1

      assert_no_selector '.field_with_errors'
    end
  end

  test "error styling is cleared when changing invoice line type" do
    visit edit_invoice_path(@invoice)

    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      type_select = find('select[name*="[type]"]')

      # Add error styling
      page.execute_script("arguments[0].closest('div').classList.add('field_with_errors')", type_select)
      assert_selector '.field_with_errors'

      # Change type should clear error
      select 'Text', from: type_select[:name]
      sleep 0.1

      assert_no_selector '.field_with_errors'
    end
  end

  test "error styling is cleared when typing in delivery note line fields" do
    visit edit_delivery_note_path(@delivery_note)

    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      title_field = find('input[name*="[title]"]')

      page.execute_script("arguments[0].closest('div').classList.add('field_with_errors')", title_field)
      assert_selector '.field_with_errors'

      title_field.fill_in with: 'New Title'
      sleep 0.1

      assert_no_selector '.field_with_errors'
    end
  end

  # Test line type field visibility
  test "invoice line field visibility changes with type selection" do
    visit edit_invoice_path(@invoice)

    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      type_select = find('select[name*="[type]"]')

      # Test item type (default)
      assert_equal 'item', type_select.value
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: true
      assert_selector '[data-line-type-target="notSubheading"]', visible: true
      assert_selector 'button[data-line-type-target="itemOnly"]', visible: true  # Product button

      # Test subheading type
      select 'Subheading', from: type_select[:name]
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: false
      assert_selector '[data-line-type-target="notSubheading"]', visible: false
      assert_selector 'button[data-line-type-target="itemOnly"]', visible: false

      # Test text type
      select 'Text', from: type_select[:name]
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: false
      assert_selector '[data-line-type-target="notSubheading"]', visible: true
      assert_selector 'button[data-line-type-target="itemOnly"]', visible: false
    end
  end

  test "delivery note line field visibility changes with type selection" do
    visit edit_delivery_note_path(@delivery_note)

    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      type_select = find('select[name*="[type]"]')

      # Test item type (default) - no rate field for delivery notes
      assert_equal 'item', type_select.value
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: true
      assert_selector '[data-line-type-target="notSubheading"]', visible: true
      assert_selector 'input[name*="[quantity]"]'
      assert_no_selector 'input[name*="[rate]"]'  # Delivery notes don't have rates

      # Test subheading type
      select 'Subheading', from: type_select[:name]
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: false
      assert_selector '[data-line-type-target="notSubheading"]', visible: false

      # Test text type
      select 'Text', from: type_select[:name]
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: false
      assert_selector '[data-line-type-target="notSubheading"]', visible: true
    end
  end

  # Test total calculation for invoices (delivery notes don't have totals)
  test "invoice total updates when modifying line values" do
    visit edit_invoice_path(@invoice)

    total_element = find('[data-invoice-lines-target="total"]')
    initial_total = total_element.text

    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      fill_in find('input[name*="[quantity]"]')[:name], with: '3'
      fill_in find('input[name*="[rate]"]')[:name], with: '20.00'
      find('input[name*="[rate]"]').native.send_keys(:tab)
    end

    sleep 0.1

    updated_total = total_element.text
    assert_not_equal initial_total, updated_total

    line_total = new_line.find('[data-line-total]').text
    assert_equal '€60.00', line_total  # 3 × 20.00
  end

  test "invoice totals clear for non-item line types" do
    visit edit_invoice_path(@invoice)

    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      # Set as item first with values
      fill_in find('input[name*="[quantity]"]')[:name], with: '2'
      fill_in find('input[name*="[rate]"]')[:name], with: '25.00'
      find('input[name*="[rate]"]').native.send_keys(:tab)
    end

    sleep 0.1

    # Should show total
    line_total = new_line.find('[data-line-total]').text
    assert_equal '€50.00', line_total

    within new_line do
      # Change to text type
      select 'Text', from: find('select[name*="[type]"]')[:name]
    end

    sleep 0.1

    # Total should clear for text type
    line_total = new_line.find('[data-line-total]').text
    assert_equal '€0.00', line_total
  end
end
