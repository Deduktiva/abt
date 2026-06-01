require "test_helper"

class DeliveryNotesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "should get index" do
    get delivery_notes_url
    assert_response :success
  end

  # Year filtering, customer filtering, and the customer-dropdown rendering are
  # covered once via the InvoicesController test (and YearFilterable via its
  # own concern test). DeliveryNotesController#index uses the same scopes and
  # the same shared dropdown partial.

  test "should show delivery note" do
    note = delivery_notes(:published_delivery_note)
    assert_nil note.invoice, "fixture should not yet be invoiced"

    get delivery_note_url(note)
    assert_response :success
    # Invoice row renders with the convert button when published but not yet invoiced
    assert_select "strong", text: "Invoice:"
    assert_select "form[action=?]", convert_to_invoice_delivery_note_path(note) do
      assert_select "button"
    end
  end

  test "published delivery note show offers PDF action, not the unusable Preview" do
    note = delivery_notes(:published_delivery_note)
    get delivery_note_url(note)
    assert_response :success
    assert_select "a[href=?]", pdf_delivery_note_path(note)
    assert_select "a[href=?]", preview_delivery_note_path(note), count: 0
  end

  test "should get new" do
    get new_delivery_note_url
    assert_response :success
  end

  test "should create delivery note" do
    assert_difference("DeliveryNote.count") do
      post delivery_notes_url, params: {
        delivery_note: {
          customer_id: customers(:good_eu).id,
          project_id: projects(:one).id,
          cust_reference: "TEST-REF",
          cust_order: "TEST-ORDER",
          delivery_start_date: Date.new(2025, 5, 1),
          delivery_end_date: Date.new(2025, 5, 31)
        }
      }
    end

    assert_redirected_to delivery_note_url(DeliveryNote.last)

    delivery_note = DeliveryNote.last
    assert_equal Date.new(2025, 5, 1), delivery_note.delivery_start_date
    assert_equal Date.new(2025, 5, 31), delivery_note.delivery_end_date
    assert_equal "May 2025", delivery_note.delivery_timeframe
  end

  test "should get edit" do
    get edit_delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_response :success
  end

  test "should update delivery note" do
    patch delivery_note_url(delivery_notes(:draft_delivery_note)), params: {
      delivery_note: { cust_reference: "UPDATED-REF" }
    }
    assert_redirected_to delivery_note_url(DeliveryNote.last)
  end

  test "should destroy delivery note" do
    assert_difference("DeliveryNote.count", -1) do
      delete delivery_note_url(delivery_notes(:draft_delivery_note))
    end

    assert_redirected_to delivery_notes_url
  end

  # require_unpublished's "Published … can not be modified" guard is covered
  # once via PublishableDocumentTest using the Invoice routes.

  test "should not destroy numbered but unpublished delivery note" do
    note = delivery_notes(:published_delivery_note)
    post unpublish_delivery_note_url(note)
    assert note.reload.document_number.present?, "unpublish must preserve the document number"

    assert_no_difference("DeliveryNote.count") do
      delete delivery_note_url(note)
    end

    assert_redirected_to delivery_note_url(note)
    assert_match "assigned document number", flash[:error]
  end

  test "should get preview pdf" do
    get preview_delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  test "should get pdf for published delivery note" do
    get pdf_delivery_note_url(delivery_notes(:published_delivery_note))
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  test "should not get pdf for draft delivery note" do
    get pdf_delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_redirected_to delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_match "Draft delivery notes can not be used for this action", flash[:error]
  end

  test "publish action redirects to show with published=1 on success" do
    note = delivery_notes(:draft_delivery_note)
    note.delivery_note_lines.create!(
      type: "item", title: "x", quantity: 1.0, position: 1
    )

    post publish_delivery_note_url(note)
    assert_redirected_to delivery_note_path(note, published: 1)
    assert_not flash[:notice].present?, "success path should not flash; the banner replaces it"

    note.reload
    assert note.published?
    assert note.document_number.present?
  end

  test "show renders post-publish banner when arriving with ?published=1" do
    get delivery_note_url(delivery_notes(:published_delivery_note), published: 1)
    assert_response :success
    assert_select ".alert-success .alert-heading", text: /published/
    assert_select ".alert-success a", text: "Download PDF"
  end

  test "show does not render post-publish banner without ?published=1" do
    get delivery_note_url(delivery_notes(:published_delivery_note))
    assert_response :success
    assert_select ".alert-success .alert-heading", count: 0
  end

  test "should unpublish delivery note" do
    published_note = delivery_notes(:published_delivery_note)
    original_number = published_note.document_number
    original_date = published_note.date

    post unpublish_delivery_note_url(published_note)
    assert_redirected_to delivery_note_url(published_note)

    published_note.reload
    assert_not published_note.published?
    assert_equal original_number, published_note.document_number,
                 "document number must survive unpublish to keep the sequence gap-free"
    assert_equal original_date, published_note.date
    assert_match "reverted to draft status", flash[:notice]

    # Re-publishing keeps the preserved number but refreshes the date — the
    # publish event genuinely happened now.
    travel_to original_date + 2.days do
      post publish_delivery_note_url(published_note)
    end

    published_note.reload
    assert published_note.published?
    assert_equal original_number, published_note.document_number
    assert_equal original_date + 2.days, published_note.date
  end

  test "should not unpublish draft delivery note" do
    post unpublish_delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_redirected_to delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_match "Draft delivery notes can not be used for this action", flash[:error]
  end

  test "should upload acceptance document for published delivery note" do
    # Create a mock PDF file
    pdf_file = Rack::Test::UploadedFile.new(
      Rails.root.join("test", "fixtures", "files", "example_logo.pdf"),
      "application/pdf"
    )

    published_note = delivery_notes(:published_delivery_note)
    assert_nil published_note.acceptance_attachment

    post upload_acceptance_delivery_note_url(published_note), params: { acceptance_pdf: pdf_file }
    assert_redirected_to delivery_note_url(published_note)

    published_note.reload
    assert published_note.acceptance_attachment.present?
    assert_equal "application/pdf", published_note.acceptance_attachment.content_type
    assert_match "uploaded successfully", flash[:notice]
  end

  test "should not upload non-PDF files as acceptance document" do
    text_file = Rack::Test::UploadedFile.new(
      StringIO.new("test content"),
      "text/plain",
      original_filename: "test.txt"
    )

    post upload_acceptance_delivery_note_url(delivery_notes(:published_delivery_note)), params: { acceptance_pdf: text_file }
    assert_redirected_to delivery_note_url(delivery_notes(:published_delivery_note))
    assert_match "Only PDF files are allowed", flash[:error]
  end

  test "should convert published delivery note to invoice" do
    published_note = delivery_notes(:published_delivery_note)
    assert_nil published_note.invoice

    post convert_to_invoice_delivery_note_url(published_note)

    published_note.reload

    assert published_note.invoice.present?, "Invoice should have been created and linked"
    assert_not published_note.invoice.published?
    assert_equal published_note.customer, published_note.invoice.customer
    assert_equal published_note.project, published_note.invoice.project
    assert_equal published_note.cust_reference, published_note.invoice.cust_reference

    # Check that the enhanced prelude includes delivery note information
    assert_match "Based on Delivery Note #{published_note.document_number}", published_note.invoice.prelude
    assert_match "Delivery Note Date:", published_note.invoice.prelude
  end

  test "convert_to_invoice leaves item line rates blank" do
    published_note = delivery_notes(:published_delivery_note)

    post convert_to_invoice_delivery_note_url(published_note)

    item_lines = published_note.reload.invoice.invoice_lines.where(type: "item")
    assert item_lines.any?, "expected at least one item line on the converted invoice"
    item_lines.each { |line| assert_nil line.rate }
  end

  test "convert_to_invoice uses the default sales tax product class for item lines" do
    published_note = delivery_notes(:published_delivery_note)
    default_class = sales_tax_product_classes(:standard)
    assert default_class.is_default?

    # Add a non-default class to make sure the default is selected, not just any row.
    SalesTaxProductClass.create!(name: "Reduced", indicator_code: "RED", is_default: false)

    post convert_to_invoice_delivery_note_url(published_note)

    published_note.reload
    item_lines = published_note.invoice.invoice_lines.where(type: "item")
    assert item_lines.any?, "expected at least one item line on the converted invoice"
    item_lines.each do |line|
      assert_equal default_class.id, line.sales_tax_product_class_id
    end
  end

  test "should not convert delivery note to invoice twice" do
    published_note = delivery_notes(:published_delivery_note)
    # Create an existing invoice link
    invoice = Invoice.create!(customer: published_note.customer, project: published_note.project)
    published_note.update!(invoice: invoice)

    assert_no_difference("Invoice.count") do
      post convert_to_invoice_delivery_note_url(published_note)
    end

    assert_redirected_to delivery_note_url(published_note)
    assert_match "already been converted", flash[:error]
  end

  test "should not convert draft delivery note to invoice" do
    assert_no_difference("Invoice.count") do
      post convert_to_invoice_delivery_note_url(delivery_notes(:draft_delivery_note))
    end

    assert_redirected_to delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_match "Draft delivery notes can not be used for this action", flash[:error]
  end

  test "should replace acceptance document" do
    published_note = delivery_notes(:published_delivery_note)

    # First upload an acceptance document
    first_pdf = Rack::Test::UploadedFile.new(
      Rails.root.join("test", "fixtures", "files", "example_logo.pdf"),
      "application/pdf"
    )
    post upload_acceptance_delivery_note_url(published_note), params: { acceptance_pdf: first_pdf }

    published_note.reload
    original_attachment_id = published_note.acceptance_attachment.id

    # Upload a replacement
    second_pdf = Rack::Test::UploadedFile.new(
      Rails.root.join("test", "fixtures", "files", "example_logo.pdf"),
      "application/pdf",
      original_filename: "replacement.pdf"
    )

    post upload_acceptance_delivery_note_url(published_note), params: { acceptance_pdf: second_pdf }

    published_note.reload
    assert published_note.acceptance_attachment.present?
    assert_not_equal original_attachment_id, published_note.acceptance_attachment.id
    assert_equal "replacement.pdf", published_note.acceptance_attachment.filename
  end

  test "should delete acceptance document" do
    published_note = delivery_notes(:published_delivery_note)

    # First upload an acceptance document
    pdf_file = Rack::Test::UploadedFile.new(
      Rails.root.join("test", "fixtures", "files", "example_logo.pdf"),
      "application/pdf"
    )
    post upload_acceptance_delivery_note_url(published_note), params: { acceptance_pdf: pdf_file }

    published_note.reload
    assert published_note.acceptance_attachment.present?

    # Delete the acceptance document
    post delete_acceptance_delivery_note_url(published_note)

    published_note.reload
    assert_nil published_note.acceptance_attachment
    assert_match "deleted successfully", flash[:notice]
  end

  test "should not delete acceptance document if none exists" do
    published_note = delivery_notes(:published_delivery_note)
    assert_nil published_note.acceptance_attachment

    post delete_acceptance_delivery_note_url(published_note)

    assert_redirected_to delivery_note_url(published_note)
    assert_match "No acceptance document to delete", flash[:error]
  end

  test "should include acceptance document info in invoice prelude when converting" do
    published_note = delivery_notes(:published_delivery_note)

    # First upload an acceptance document
    pdf_file = Rack::Test::UploadedFile.new(
      Rails.root.join("test", "fixtures", "files", "example_logo.pdf"),
      "application/pdf",
      original_filename: "signed_acceptance.pdf"
    )
    post upload_acceptance_delivery_note_url(published_note), params: { acceptance_pdf: pdf_file }

    published_note.reload
    assert published_note.acceptance_attachment.present?

    # Ensure there's a sales tax product class for the conversion
    SalesTaxProductClass.find_or_create_by(name: "Standard") do |tax_class|
      tax_class.indicator_code = "STD"
    end

    # Convert to invoice
    post convert_to_invoice_delivery_note_url(published_note)

    published_note.reload
    assert published_note.invoice.present?

    # Check that the prelude includes acceptance document information
    assert_match "Based on Delivery Note #{published_note.document_number}", published_note.invoice.prelude
    assert_match "Acceptance Document: signed_acceptance.pdf", published_note.invoice.prelude
  end

  test "should get email preview json" do
    get preview_email_delivery_note_url(delivery_notes(:published_delivery_note), format: :json)
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?("subject")
    assert json_response["emailable"]
  end

  test "send_email returns 200 for JSON requests and marks email sent" do
    note = delivery_notes(:published_delivery_note)
    note.update_column(:email_sent_at, nil)

    perform_enqueued_jobs do
      post send_email_delivery_note_url(note),
           headers: { "Accept" => "application/json" }
    end

    assert_response :success
    assert_not_nil note.reload.email_sent_at
  end

  test "send_email redirects for HTML requests" do
    note = delivery_notes(:published_delivery_note)
    post send_email_delivery_note_url(note)
    assert_redirected_to delivery_note_url(note)
    assert_match "E-Mail queued for sending.", flash[:notice]
  end

  test "send_email returns an error status for JSON when no recipient is configured" do
    note = delivery_notes(:published_delivery_note)
    note.customer.customer_contacts.destroy_all
    note.update_column(:email_sent_at, nil)

    post send_email_delivery_note_url(note),
         headers: { "Accept" => "application/json" }

    assert_response :unprocessable_content
    assert_nil note.reload.email_sent_at
  end

  test "should bulk send emails to selected delivery notes" do
    published_note = delivery_notes(:published_delivery_note)

    post bulk_send_emails_delivery_notes_url, params: { delivery_note_ids: [ published_note.id ] }
    assert_redirected_to delivery_notes_url
    assert_match "1 emails queued for sending", flash[:notice]
  end

  test "should not bulk send emails if no delivery notes selected" do
    post bulk_send_emails_delivery_notes_url, params: { delivery_note_ids: [] }
    assert_redirected_to delivery_notes_url
    assert_match "No delivery notes selected", flash[:alert]
  end

  test "should send bulk email when multiple delivery notes for same customer" do
    customer = customers(:good_eu)

    note1 = create_published_delivery_note(customer: customer, document_number: "DN-2025-002", cust_reference: "BULK-TEST-1")
    note2 = create_published_delivery_note(customer: customer, document_number: "DN-2025-003", cust_reference: "BULK-TEST-2")

    perform_enqueued_jobs do
      post bulk_send_emails_delivery_notes_url, params: { delivery_note_ids: [ note1.id, note2.id ] }
    end
    assert_redirected_to delivery_notes_url
    assert_match "2 emails queued for sending", flash[:notice]
    assert_not_nil note1.reload.email_sent_at
    assert_not_nil note2.reload.email_sent_at
  end

  test "should send individual emails when delivery notes are for different customers" do
    note1 = delivery_notes(:published_delivery_note)  # good_eu customer
    note2 = create_published_delivery_note(customer: customers(:good_national), document_number: "DN-2025-004", cust_reference: "DIFF-CUSTOMER")

    post bulk_send_emails_delivery_notes_url, params: { delivery_note_ids: [ note1.id, note2.id ] }
    assert_redirected_to delivery_notes_url
    assert_match "2 emails queued for sending", flash[:notice]
  end
end
