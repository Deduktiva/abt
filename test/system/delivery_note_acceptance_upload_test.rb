require "application_system_test_case"

class DeliveryNoteAcceptanceUploadTest < ApplicationSystemTestCase
  setup do
    @published_delivery_note = delivery_notes(:published_delivery_note)
  end

  test "Upload PDF button prevents submission when no file selected" do
    visit delivery_note_path(@published_delivery_note)

    # Verify we're on a published delivery note with no acceptance document
    assert_text "Acceptance Document"
    assert_button "Upload PDF"

    # Find the file input field - should have no files
    file_input = find('input[type="file"][name="acceptance_pdf"]', visible: :all)

    # Verify no file is selected initially
    files_count = page.execute_script(<<~JS) || 0
      const fileInput = document.querySelector('input[type="file"][name="acceptance_pdf"]');
      return fileInput ? fileInput.files.length : 0;
    JS
    assert_equal 0, files_count, "No file should be selected initially"

    # Set up form submission tracking to verify it's prevented
    page.execute_script(<<~JS)
      window.formSubmissionAttempted = false;
      window.formActuallySubmitted = false;
      const form = document.querySelector('form[method="post"]');
      if (form) {
        form.addEventListener('submit', function(e) {
          window.formSubmissionAttempted = true;
          // Don't prevent in test - we want to see if Stimulus prevents it
        });
        // Override form.submit() to track if it gets called
        const originalSubmit = form.submit;
        form.submit = function() {
          window.formActuallySubmitted = true;
          return originalSubmit.call(this);
        };
      }
    JS

    # Record current URL to verify we don't navigate away
    current_url = current_path

    # Click the Upload PDF button without selecting a file
    click_button "Upload PDF"

    # Wait a moment for any form submission attempt
    using_wait_time(2) do
      # Verify we stayed on the same page (form wasn't submitted)
      assert_current_path current_url
    end

    # Verify the button is still there (form wasn't submitted)
    assert_button "Upload PDF"

    # The behavior we're testing is that clicking Upload PDF without a file
    # should either trigger the file dialog or prevent form submission
    # In headless mode, we can't test file dialog, but we can verify form doesn't submit
  end

  test "file upload form elements are properly configured" do
    visit delivery_note_path(@published_delivery_note)

    # Verify we're on a published delivery note with no acceptance document
    assert_text "Acceptance Document"
    assert_button "Upload PDF"

    # Verify the basic form structure exists
    assert_selector 'form'
    assert_selector 'input[type="file"][name="acceptance_pdf"]'
    assert_selector 'input[type="submit"], button[type="submit"]'

    # Verify the form accepts PDF files
    file_input = find('input[type="file"][name="acceptance_pdf"]', visible: :all)
    assert file_input['accept'] == 'application/pdf', "File input should only accept PDF files"

    # This test ensures the basic file upload infrastructure is in place
    # and working in headless mode, without requiring complex JavaScript interactions
  end

  test "Replace button prevents submission when no file selected" do
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

    # Find the file input field - should have no files
    file_input = find('input[type="file"][name="acceptance_pdf"]', visible: :all)

    # Verify no file is selected initially
    files_count = page.execute_script(<<~JS) || 0
      const fileInput = document.querySelector('input[type="file"][name="acceptance_pdf"]');
      return fileInput ? fileInput.files.length : 0;
    JS
    assert_equal 0, files_count, "No file should be selected initially"

    # Record current URL to verify we don't navigate away
    current_url = current_path

    # Click Replace button without selecting a file
    click_button "Replace"

    # Wait a moment for any form submission attempt
    using_wait_time(2) do
      # Verify we stayed on the same page (form wasn't submitted)
      assert_current_path current_url
    end

    # Form should not have submitted - button should still be there
    assert_button "Replace"

    # The behavior we're testing is that clicking Replace without a file
    # should either trigger the file dialog or prevent form submission
    # In headless mode, we can't test file dialog, but we can verify form doesn't submit
  end
end
