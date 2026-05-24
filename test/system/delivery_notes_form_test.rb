require 'application_system_test_case'

class DeliveryNotesFormTest < ApplicationSystemTestCase
  setup do
    @delivery_note = delivery_notes(:draft_delivery_note)
  end

  test "clear-date button empties the delivery_end_date field" do
    visit edit_delivery_note_path(@delivery_note)

    field = find_field('delivery_note[delivery_end_date]', match: :first)
    assert_not_equal '', field.value, 'fixture should provide a non-empty end date'

    within(field.find(:xpath, '..')) do
      click_button '×'
    end

    assert_equal '', find_field('delivery_note[delivery_end_date]', match: :first).value
  end
end
