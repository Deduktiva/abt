require "application_system_test_case"

class DeliveryNoteLinesTest < ApplicationSystemTestCase
  setup do
    @delivery_note = delivery_notes(:draft_delivery_note)
  end

  test "adding new lines to delivery note works correctly" do
    visit edit_delivery_note_path(@delivery_note)

    initial_line_count = all('[data-line-index]').count
    click_button "Add Line"

    assert_selector '[data-line-index]', count: initial_line_count + 1
    new_line = all('[data-line-index]').last

    # Verify new line has correct defaults
    position_field = new_line.find('input[name*="[position]"]', visible: false)
    assert_equal (initial_line_count + 1).to_s, position_field.value

    type_select = new_line.find('select[name*="[type]"]')
    assert_equal 'item', type_select.value

    # Verify delivery note-specific fields (quantity but no rate)
    within new_line do
      assert_selector 'input[name*="[quantity]"]'
      assert_no_selector 'input[name*="[rate]"]'  # Delivery notes don't have rates
      assert_selector 'div[data-line-type-target="itemOnly"]', visible: true
    end
  end

  test "delivery note line types work correctly" do
    visit edit_delivery_note_path(@delivery_note)

    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      type_select = find('select[name*="[type]"]')

      # Test all delivery note line types using the constant from the model
      DeliveryNoteLine::TYPE_OPTIONS.each do |display_name, value|
        select display_name, from: type_select[:name]
        assert_equal value, type_select.value

        case value
        when 'subheading'
          assert_selector 'div[data-line-type-target="itemOnly"]', visible: false
          assert_selector '[data-line-type-target="notSubheading"]', visible: false
        when 'item'
          assert_selector 'div[data-line-type-target="itemOnly"]', visible: true
          assert_selector '[data-line-type-target="notSubheading"]', visible: true
          assert_selector 'input[name*="[quantity]"]'
        else # text, plain
          assert_selector 'div[data-line-type-target="itemOnly"]', visible: false
          assert_selector '[data-line-type-target="notSubheading"]', visible: true
        end
      end
    end
  end

  test "quantity field validation for delivery note items" do
    visit edit_delivery_note_path(@delivery_note)

    click_button "Add Line"
    new_line = all('[data-line-index]').last

    within new_line do
      # Ensure it's an item type
      type_select = find('select[name*="[type]"]')
      select 'Item', from: type_select[:name] if type_select.value != 'item'

      # Verify quantity field is visible and accessible for items
      quantity_field = find('input[name*="[quantity]"]')
      assert quantity_field.visible?

      # Fill in required fields
      fill_in find('input[name*="[title]"]')[:name], with: 'Test Item'
      quantity_field.set('10')  # Set a valid quantity

      # Verify the field works correctly
      assert_equal '10', quantity_field.value
    end
  end
end
