require "application_system_test_case"

class InvoiceLinesTest < ApplicationSystemTestCase
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

  test "product dropdown elements are present for invoice lines" do
    visit edit_invoice_path(@invoice)
    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      # Verify product dropdown elements are present
      assert_selector '[data-product-dropdown]', visible: false
      assert_selector '[data-product-select]', visible: false

      # Only check for product button if products exist
      if Product.exists?
        assert_selector 'button[data-line-type-target="itemOnly"]'
      end
    end
  end
end
