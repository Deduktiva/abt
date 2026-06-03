require "application_system_test_case"

class DeliveryNoteAcceptanceUploadTest < ApplicationSystemTestCase
  setup do
    @published_delivery_note = delivery_notes(:published_delivery_note)
  end

  test "Upload PDF button does not submit the form when no file is selected" do
    visit delivery_note_path(@published_delivery_note)
    assert_button "Upload PDF"

    file_input = find('input[type="file"][name="acceptance_pdf"]', visible: :all)
    assert_equal "application/pdf", file_input["accept"]

    starting_path = current_path
    click_button "Upload PDF"

    using_wait_time(2) do
      assert_current_path starting_path
    end
    assert_button "Upload PDF"
  end
end
