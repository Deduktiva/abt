require 'test_helper'

class DeliveryNotesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get delivery_notes_url
    assert_response :success
  end

  test "should get index with year filter" do
    # Create delivery notes in different years
    DeliveryNote.create!(
      customer: customers(:good_eu),
      project: projects(:one),
      cust_reference: "2023-TEST",
      date: Date.new(2023, 6, 15),
      delivery_start_date: Date.new(2023, 6, 15)
    )

    DeliveryNote.create!(
      customer: customers(:good_eu),
      project: projects(:one),
      cust_reference: "2024-TEST",
      date: Date.new(2024, 6, 15),
      delivery_start_date: Date.new(2024, 6, 15)
    )

    # Test current year (default)
    get delivery_notes_url
    assert_response :success

    # Test specific year filter
    get delivery_notes_url(year: 2023)
    assert_response :success
    # Verify the page contains the 2023 note reference but not 2024
    assert_select 'td', text: '2023-TEST'
    assert_select 'td', text: '2024-TEST', count: 0
  end

  test "should include draft delivery notes with nil date in current year" do
    # Create a draft delivery note (no date)
    DeliveryNote.create!(
      customer: customers(:good_eu),
      project: projects(:one),
      cust_reference: "DRAFT-NO-DATE",
      delivery_start_date: Date.current
      # date is nil for draft notes
    )

    get delivery_notes_url
    assert_response :success
    assert_select 'td', text: 'DRAFT-NO-DATE'
  end

  test "should show delivery note" do
    get delivery_note_url(delivery_notes(:published_delivery_note))
    assert_response :success
  end

  test "should get new" do
    get new_delivery_note_url
    assert_response :success
  end

  test "should create delivery note" do
    assert_difference('DeliveryNote.count') do
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
    assert_difference('DeliveryNote.count', -1) do
      delete delivery_note_url(delivery_notes(:draft_delivery_note))
    end

    assert_redirected_to delivery_notes_url
  end

  test "should not destroy published delivery note" do
    assert_no_difference('DeliveryNote.count') do
      delete delivery_note_url(delivery_notes(:published_delivery_note))
    end

    assert_redirected_to delivery_notes_url
    assert_match 'cannot be deleted', flash[:alert]
  end

  test "should get preview pdf" do
    get preview_delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  test "should get pdf for published delivery note" do
    get pdf_delivery_note_url(delivery_notes(:published_delivery_note))
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  test "should not get pdf for draft delivery note" do
    get pdf_delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_redirected_to delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_match 'Draft delivery notes can not be used for this action', flash[:error]
  end

  test "should unpublish delivery note" do
    published_note = delivery_notes(:published_delivery_note)

    post unpublish_delivery_note_url(published_note)
    assert_redirected_to delivery_note_url(published_note)

    published_note.reload
    assert_not published_note.published?
    assert_nil published_note.document_number
    assert_nil published_note.date
    assert_match 'reverted to draft status', flash[:notice]
  end

  test "should not unpublish draft delivery note" do
    post unpublish_delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_redirected_to delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_match 'Draft delivery notes can not be used for this action', flash[:error]
  end

  test "should upload acceptance document for published delivery note" do
    # Create a mock PDF file
    pdf_file = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'example_logo.pdf'),
      'application/pdf'
    )

    published_note = delivery_notes(:published_delivery_note)
    assert_nil published_note.acceptance_attachment

    post upload_acceptance_delivery_note_url(published_note), params: { acceptance_pdf: pdf_file }
    assert_redirected_to delivery_note_url(published_note)

    published_note.reload
    assert published_note.acceptance_attachment.present?
    assert_equal 'application/pdf', published_note.acceptance_attachment.content_type
    assert_match 'uploaded successfully', flash[:notice]
  end

  test "should not upload non-PDF files as acceptance document" do
    text_file = Rack::Test::UploadedFile.new(
      StringIO.new("test content"),
      'text/plain',
      original_filename: 'test.txt'
    )

    post upload_acceptance_delivery_note_url(delivery_notes(:published_delivery_note)), params: { acceptance_pdf: text_file }
    assert_redirected_to delivery_note_url(delivery_notes(:published_delivery_note))
    assert_match 'Only PDF files are allowed', flash[:error]
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

  test "convert_to_invoice uses the default sales tax product class for item lines" do
    published_note = delivery_notes(:published_delivery_note)
    default_class = sales_tax_product_classes(:standard)
    assert default_class.is_default?

    # Add a non-default class to make sure the default is selected, not just any row.
    SalesTaxProductClass.create!(name: "Reduced", indicator_code: "RED", is_default: false)

    post convert_to_invoice_delivery_note_url(published_note)

    published_note.reload
    item_lines = published_note.invoice.invoice_lines.where(type: 'item')
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

    assert_no_difference('Invoice.count') do
      post convert_to_invoice_delivery_note_url(published_note)
    end

    assert_redirected_to delivery_note_url(published_note)
    assert_match 'already been converted', flash[:error]
  end

  test "should not convert draft delivery note to invoice" do
    assert_no_difference('Invoice.count') do
      post convert_to_invoice_delivery_note_url(delivery_notes(:draft_delivery_note))
    end

    assert_redirected_to delivery_note_url(delivery_notes(:draft_delivery_note))
    assert_match 'Draft delivery notes can not be used for this action', flash[:error]
  end

  test "should replace acceptance document" do
    published_note = delivery_notes(:published_delivery_note)

    # First upload an acceptance document
    first_pdf = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'example_logo.pdf'),
      'application/pdf'
    )
    post upload_acceptance_delivery_note_url(published_note), params: { acceptance_pdf: first_pdf }

    published_note.reload
    original_attachment_id = published_note.acceptance_attachment.id

    # Upload a replacement
    second_pdf = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'example_logo.pdf'),
      'application/pdf',
      original_filename: 'replacement.pdf'
    )

    post upload_acceptance_delivery_note_url(published_note), params: { acceptance_pdf: second_pdf }

    published_note.reload
    assert published_note.acceptance_attachment.present?
    assert_not_equal original_attachment_id, published_note.acceptance_attachment.id
    assert_equal 'replacement.pdf', published_note.acceptance_attachment.filename
  end

  test "should delete acceptance document" do
    published_note = delivery_notes(:published_delivery_note)

    # First upload an acceptance document
    pdf_file = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'example_logo.pdf'),
      'application/pdf'
    )
    post upload_acceptance_delivery_note_url(published_note), params: { acceptance_pdf: pdf_file }

    published_note.reload
    assert published_note.acceptance_attachment.present?

    # Delete the acceptance document
    post delete_acceptance_delivery_note_url(published_note)

    published_note.reload
    assert_nil published_note.acceptance_attachment
    assert_match 'deleted successfully', flash[:notice]
  end

  test "should not delete acceptance document if none exists" do
    published_note = delivery_notes(:published_delivery_note)
    assert_nil published_note.acceptance_attachment

    post delete_acceptance_delivery_note_url(published_note)

    assert_redirected_to delivery_note_url(published_note)
    assert_match 'No acceptance document to delete', flash[:error]
  end

  test "should include acceptance document info in invoice prelude when converting" do
    published_note = delivery_notes(:published_delivery_note)

    # First upload an acceptance document
    pdf_file = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'example_logo.pdf'),
      'application/pdf',
      original_filename: 'signed_acceptance.pdf'
    )
    post upload_acceptance_delivery_note_url(published_note), params: { acceptance_pdf: pdf_file }

    published_note.reload
    assert published_note.acceptance_attachment.present?

    # Ensure there's a sales tax product class for the conversion
    SalesTaxProductClass.find_or_create_by(name: 'Standard') do |tax_class|
      tax_class.indicator_code = 'STD'
    end

    # Convert to invoice
    post convert_to_invoice_delivery_note_url(published_note)

    published_note.reload
    assert published_note.invoice.present?

    # Check that the prelude includes acceptance document information
    assert_match "Based on Delivery Note #{published_note.document_number}", published_note.invoice.prelude
    assert_match "Acceptance Document: signed_acceptance.pdf", published_note.invoice.prelude
  end

  test "should get email preview" do
    get preview_email_delivery_note_url(delivery_notes(:published_delivery_note))
    assert_response :success
  end

  test "should get email preview json" do
    get preview_email_delivery_note_url(delivery_notes(:published_delivery_note), format: :json)
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?('subject')
    assert json_response.key?('html_body')
  end

  test "should bulk send emails to selected delivery notes" do
    published_note = delivery_notes(:published_delivery_note)

    post bulk_send_emails_delivery_notes_url, params: { delivery_note_ids: [ published_note.id ] }
    assert_redirected_to delivery_notes_url
    assert_match '1 emails queued for sending', flash[:notice]
  end

  test "should not bulk send emails if no delivery notes selected" do
    post bulk_send_emails_delivery_notes_url, params: { delivery_note_ids: [] }
    assert_redirected_to delivery_notes_url
    assert_match 'No delivery notes selected', flash[:alert]
  end

  test "should send bulk email when multiple delivery notes for same customer" do
    customer = customers(:good_eu)

    note1 = create_published_delivery_note(customer: customer, document_number: "DN-2025-002", cust_reference: "BULK-TEST-1")
    note2 = create_published_delivery_note(customer: customer, document_number: "DN-2025-003", cust_reference: "BULK-TEST-2")

    post bulk_send_emails_delivery_notes_url, params: { delivery_note_ids: [ note1.id, note2.id ] }
    assert_redirected_to delivery_notes_url
    assert_match '2 emails queued for sending', flash[:notice]
  end

  test "should send individual emails when delivery notes are for different customers" do
    note1 = delivery_notes(:published_delivery_note)  # good_eu customer
    note2 = create_published_delivery_note(customer: customers(:good_national), document_number: "DN-2025-004", cust_reference: "DIFF-CUSTOMER")

    post bulk_send_emails_delivery_notes_url, params: { delivery_note_ids: [ note1.id, note2.id ] }
    assert_redirected_to delivery_notes_url
    assert_match '2 emails queued for sending', flash[:notice]
  end

  private

  def create_published_delivery_note(customer:, document_number:, cust_reference:)
    DeliveryNote.new(
      customer: customer,
      project: projects(:one),
      document_number: document_number,
      published: true,
      date: Date.current,
      cust_reference: cust_reference,
      delivery_start_date: Date.current,
      delivery_note_lines_attributes: [
        { type: 'item', title: 'Item', description: 'desc', quantity: 1.0, position: 1 }
      ]
    ).tap(&:save!)
  end
end
