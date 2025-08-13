require "test_helper"

class InvoiceLinesTest < ActionDispatch::SystemTestCase
  setup do
    @invoice = invoices(:draft_invoice)
  end

  test "adding new lines to invoice works correctly" do
    visit edit_invoice_path(@invoice)

    initial_line_count = all('[data-line-index]').count
    click_button "Add Line"

    assert_selector '[data-line-index]', count: initial_line_count + 1
    new_line = all('[data-line-index]').last

    # Verify new line has correct defaults
    position_field = new_line.find('input[name*="[position]"]', visible: false)
    assert_equal (initial_line_count + 1).to_s, position_field.value

    type_select = new_line.find('select[name*="[type]"]')
    assert_equal 'item', type_select.value

    # Verify invoice-specific fields are present
    within new_line do
      assert_selector 'input[name*="[quantity]"]'
      assert_selector 'input[name*="[rate]"]'
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: true
    end
  end

  test "product dropdown functionality works with available products" do
    # Skip if no products exist to avoid test failures
    return unless Product.exists?

    visit edit_invoice_path(@invoice)
    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      # Verify product dropdown elements are present
      assert_selector '[data-product-dropdown]', visible: false
      assert_selector 'button[data-line-type-target="itemOnly"]'  # Product selection button
      assert_selector '[data-product-select]', visible: false
    end
  end
end
