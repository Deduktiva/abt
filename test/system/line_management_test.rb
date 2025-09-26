require "application_system_test_case"

class LineManagementTest < ApplicationSystemTestCase
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

    # Get original field names
    original_first = lines[0].find('input[name*="[title]"]')[:name]
    original_second = lines[1].find('input[name*="[title]"]')[:name]

    # Move second line up
    within lines[1] do
      click_button "▲"
    end

    sleep 0.1

    # Check that field names have been reindexed correctly
    updated_lines = all('[data-line-index]')
    new_first = updated_lines[0].find('input[name*="[title]"]')[:name]
    new_second = updated_lines[1].find('input[name*="[title]"]')[:name]

    # Field names should have changed (indicating reindexing occurred)
    assert_not_equal original_first, new_first
    assert_not_equal original_second, new_second
  end

  test "form field names are reindexed after reordering delivery note lines" do
    visit edit_delivery_note_path(@delivery_note)

    lines = all('[data-line-index]')
    original_first = lines[0].find('input[name*="[title]"]')[:name]

    within lines[1] do
      click_button "▲"
    end

    sleep 0.1

    updated_lines = all('[data-line-index]')
    new_first = updated_lines[0].find('input[name*="[title]"]')[:name]

    # Field name should have changed
    assert_not_equal original_first, new_first
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

  # Test removing the last line
  test "can remove the last line from invoice and delivery note" do
    # Test with invoice: Add one line, then remove it
    visit edit_invoice_path(@invoice)

    # Remove existing lines to get down to single line scenario
    initial_count = all('[data-line-index]').count
    all('[data-line-index]')[1..-1].each do |line|
      within line do
        click_button "🗑"
      end
    end

    # Should have one line left
    assert_selector '[data-line-index]', count: 1

    # Remove the last line - should work now
    within first('[data-line-index]') do
      click_button "🗑"
    end

    # Persisted line should be hidden but marked for destruction
    hidden_line = first('[data-line-index]', visible: false)
    destroy_field = hidden_line.find('input[name*="[_destroy]"]', visible: false)
    assert_equal '1', destroy_field.value

    # Test with delivery note: similar scenario
    visit edit_delivery_note_path(@delivery_note)

    # Remove all but one line
    all('[data-line-index]')[1..-1].each do |line|
      within line do
        click_button "🗑"
      end
    end

    # Remove the last line - should work now
    within first('[data-line-index]') do
      click_button "🗑"
    end

    # Should be marked for destruction
    hidden_line = first('[data-line-index]', visible: false)
    destroy_field = hidden_line.find('input[name*="[_destroy]"]', visible: false)
    assert_equal '1', destroy_field.value
  end
end
