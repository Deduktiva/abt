require "application_system_test_case"

# Line add/remove/reorder/type-visibility live in BaseLinesController and are
# exercised through the Invoice routes here. DeliveryNote wires the same JS
# the same way; we trust that and don't mirror these cases under DN.
# DN-specific assertions (no [rate] input) live in delivery_note_lines_test.rb.
class LineManagementTest < ApplicationSystemTestCase
  setup do
    @invoice = invoices(:draft_invoice)

    # Add test lines to work with
    @invoice.invoice_lines.create!(
      type: "item", title: "First Item", position: 1,
      quantity: 1, rate: 10.0, amount: 10.0
    )
    @invoice.invoice_lines.create!(
      type: "text", title: "Second Text", position: 2, amount: 0
    )
  end

  # Test removing persisted lines
  test "removing persisted invoice lines marks them for destruction" do
    visit edit_invoice_path(@invoice)

    first_line = first("[data-line-index]")
    within first_line do
      find('button[title="Remove line"]').click
    end

    # Persisted line should be hidden, not removed
    assert_not first_line.visible?
    destroy_field = first_line.find('input[name*="[_destroy]"]', visible: false)
    assert_equal "1", destroy_field.value
  end

  # Test removing new lines
  test "removing new invoice lines removes them from DOM" do
    visit edit_invoice_path(@invoice)

    initial_count = all("[data-line-index]").count
    click_button "Add Line"
    assert_selector "[data-line-index]", count: initial_count + 1

    # Remove the new line
    new_line = all("[data-line-index]").last
    within new_line do
      find('button[title="Remove line"]').click
    end

    # New line should be completely removed from DOM
    assert_selector "[data-line-index]", count: initial_count
  end

  # Test line reordering
  test "moving invoice lines up reorders them correctly" do
    visit edit_invoice_path(@invoice)

    lines = all("[data-line-index]")
    first_title = lines[0].find('input[name*="[title]"]').value
    second_title = lines[1].find('input[name*="[title]"]').value

    # Move second line up
    within lines[1] do
      click_button "▲"
    end

    updated_lines = all("[data-line-index]")
    new_first_title = updated_lines[0].find('input[name*="[title]"]').value
    new_second_title = updated_lines[1].find('input[name*="[title]"]').value

    assert_equal second_title, new_first_title
    assert_equal first_title, new_second_title

    # Verify positions are updated
    assert_equal "1", updated_lines[0].find('input[name*="[position]"]', visible: false).value
    assert_equal "2", updated_lines[1].find('input[name*="[position]"]', visible: false).value
  end

  test "moving invoice lines down reorders them correctly" do
    visit edit_invoice_path(@invoice)

    lines = all("[data-line-index]")
    first_title = lines[0].find('input[name*="[title]"]').value
    second_title = lines[1].find('input[name*="[title]"]').value

    # Move first line down
    within lines[0] do
      click_button "▼"
    end

    updated_lines = all("[data-line-index]")
    new_first_title = updated_lines[0].find('input[name*="[title]"]').value
    new_second_title = updated_lines[1].find('input[name*="[title]"]').value

    assert_equal second_title, new_first_title
    assert_equal first_title, new_second_title
  end

  # Test form field reindexing
  test "form field names are reindexed after reordering invoice lines" do
    visit edit_invoice_path(@invoice)

    lines = all("[data-line-index]")

    # Get original field names
    original_first = lines[0].find('input[name*="[title]"]')[:name]
    original_second = lines[1].find('input[name*="[title]"]')[:name]

    # Move second line up
    within lines[1] do
      click_button "▲"
    end

    # Check that field names have been reindexed correctly
    updated_lines = all("[data-line-index]")
    new_first = updated_lines[0].find('input[name*="[title]"]')[:name]
    new_second = updated_lines[1].find('input[name*="[title]"]')[:name]

    # Field names should have changed (indicating reindexing occurred)
    assert_not_equal original_first, new_first
    assert_not_equal original_second, new_second
  end

  test "invoice line field visibility changes with type selection" do
    visit edit_invoice_path(@invoice)

    click_button "Add Line"
    new_line = all("[data-line-index]").last

    within new_line do
      type_select = find('select[name*="[type]"]')
      assert_equal "item", type_select.value
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: true
      assert_selector '[data-line-type-target="notSubheading"]', visible: true

      select "Subheading", from: type_select[:name]
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: :hidden
      assert_selector '[data-line-type-target="notSubheading"]', visible: :hidden

      select "Text", from: type_select[:name]
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: :hidden
      assert_selector '[data-line-type-target="notSubheading"]', visible: true
    end
  end

  test "invoice total updates in the issuer currency when modifying line values" do
    issuer_companies(:one).update!(currency: "USD")
    visit edit_invoice_path(@invoice)

    total_element = find('[data-invoice-lines-target="total"]')
    initial_total = total_element.text

    click_button "Add Line"
    new_line = all("[data-line-index]").last

    within new_line do
      fill_in find('input[name*="[quantity]"]')[:name], with: "3"
      fill_in find('input[name*="[rate]"]')[:name], with: "20.00"
      find('input[name*="[rate]"]').native.send_keys(:tab)
    end

    # assert_selector auto-waits for the line total before we read the running total.
    assert_selector "[data-line-total]", text: "$60.00"
    assert_not_equal initial_total, total_element.text
  end

  # Test removing the last line
  test "can remove the last invoice line" do
    visit edit_invoice_path(@invoice)

    # Remove existing lines to get down to single line scenario
    all("[data-line-index]")[1..-1].each do |line|
      within line do
        find('button[title="Remove line"]').click
      end
    end

    # Should have one line left
    assert_selector "[data-line-index]", count: 1

    # Remove the last line - should work now
    within first("[data-line-index]") do
      find('button[title="Remove line"]').click
    end

    # Persisted line should be hidden but marked for destruction
    hidden_line = first("[data-line-index]", visible: false)
    destroy_field = hidden_line.find('input[name*="[_destroy]"]', visible: false)
    assert_equal "1", destroy_field.value
  end
end
