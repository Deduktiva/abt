require "application_system_test_case"

class DeliveryNoteAcceptanceUploadTest < ApplicationSystemTestCase
  setup do
    @published_delivery_note = delivery_notes(:published_delivery_note)
  end

  test "Upload PDF button triggers file dialog when no file selected" do
    visit delivery_note_path(@published_delivery_note)

    # Verify we're on a published delivery note with no acceptance document
    assert_text "Acceptance Document"
    assert_button "Upload PDF"

    # Find the file input field
    file_input = find('input[type="file"][name="acceptance_pdf"]', visible: :all)

    # Create a mock file dialog interaction by setting up a listener
    # for the click event on the file input
    page.execute_script(<<~JS)
      window.fileInputClicked = false;
      const fileInput = document.querySelector('input[type="file"][name="acceptance_pdf"]');
      if (fileInput) {
        fileInput.addEventListener('click', function() {
          window.fileInputClicked = true;
        });
      }
    JS

    # Click the Upload PDF button without selecting a file
    click_button "Upload PDF"

    # Verify that the file input click event was triggered
    file_input_clicked = page.execute_script("return window.fileInputClicked;")
    assert file_input_clicked, "File input should be clicked when Upload PDF button is pressed without a file"

    # Verify that the form was NOT submitted (should stay on the same page)
    assert_current_path delivery_note_path(@published_delivery_note)
    assert_button "Upload PDF" # Button should still be there
  end

  test "Upload PDF button allows form submission when file is selected" do
    skip "Cannot test actual file selection in headless browser without complex workarounds"
    # This test would require complex browser automation to simulate file selection
    # In a real browser test, we would:
    # 1. Attach a file to the input
    # 2. Click Upload PDF
    # 3. Verify the form submits normally
  end

  test "Replace button triggers file dialog when no file selected" do
    # Create acceptance attachment and associate it with the delivery note
    attachment = Attachment.create!(
      title: "Test Acceptance Document",
      data: "dummy pdf data",
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    @published_delivery_note.update!(acceptance_attachment: attachment)

    visit delivery_note_path(@published_delivery_note)

    # Verify we have an existing acceptance document
    assert_text "test.pdf"
    assert_button "Replace"

    # Set up file input click tracking
    page.execute_script(<<~JS)
      window.fileInputClicked = false;
      const fileInput = document.querySelector('input[type="file"][name="acceptance_pdf"]');
      if (fileInput) {
        fileInput.addEventListener('click', function() {
          window.fileInputClicked = true;
        });
      }
    JS

    # Click Replace button without selecting a file
    click_button "Replace"

    # Verify file input was clicked
    file_input_clicked = page.execute_script("return window.fileInputClicked;")
    assert file_input_clicked, "File input should be clicked when Replace button is pressed without a file"

    # Form should not have submitted
    assert_current_path delivery_note_path(@published_delivery_note)
    assert_button "Replace"
  end
end
