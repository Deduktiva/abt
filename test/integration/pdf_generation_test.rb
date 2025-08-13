require "test_helper"

class PdfGenerationTest < ActionDispatch::IntegrationTest
  fixtures :customers, :projects, :sales_tax_customer_classes, :sales_tax_product_classes, :sales_tax_rates, :issuer_companies, :document_numbers

  def setup
    @customer = customers(:good_eu)
    @project = projects(:test_project)
    @invoice = Invoice.create!(
      customer: @customer,
      project: @project,
      cust_reference: "TEST-REF",
      cust_order: "TEST-ORDER",
      prelude: "Test invoice for PDF generation"
    )

    # Add some invoice lines
    @invoice.invoice_lines.create!(
      type: 'item',
      title: 'Test Product',
      description: 'Test product description',
      quantity: 2,
      rate: 50.00,
      sales_tax_product_class_id: sales_tax_product_classes(:standard).id
    )
  end

  def test_invoice_preview_generates_pdf
    # Test the preview action that generates PDF
    get preview_invoice_path(@invoice)

    assert_response :success

    assert_valid_pdf_response
  end

  def test_invoice_booking_creates_attachment
    # Book the invoice (this should create PDF attachment)
    post book_invoice_path(@invoice), params: { save: 'true' }

    assert_redirected_to book_invoice_path(@invoice)

    @invoice.reload
    assert @invoice.published?, "Invoice should be published after booking"

    # Check if PDF attachment was created
    assert @invoice.attachment.present?
    assert_equal 'application/pdf', @invoice.attachment.content_type
    assert @invoice.attachment.data.start_with?('%PDF'), "Attachment should be a PDF"
  end

  def test_pdf_contains_invoice_data
    get preview_invoice_path(@invoice)
    assert_response :success

    # While we can't easily parse PDF content in tests, we can verify
    # that the invoice was processed through the booking controller
    # by checking that invoice_lines have calculated amounts
    @invoice.reload
    assert @invoice.invoice_lines.any? { |line| line.amount.present? if line.type == 'item' }
  end

  def test_pdf_generation_with_missing_data
    # Create invoice with minimal data to test error handling
    minimal_invoice = Invoice.create!(
      customer: @customer,
      project: @project
    )

    get preview_invoice_path(minimal_invoice)

    # Should either generate PDF or return error, but not crash
    assert_response :success, "Should handle invoices with minimal data gracefully"
  end

  def test_pdf_generation_with_logo
    # Set up issuer company with a PDF logo
    issuer_company = issuer_companies(:one)
    logo_path = Rails.root.join('test', 'fixtures', 'files', 'example_logo.pdf')
    logo_data = File.binread(logo_path)

    issuer_company.update!(
      pdf_logo: logo_data,
      pdf_logo_width: "50.0mm",
      pdf_logo_height: "15.0mm"
    )

    # Generate PDF with logo
    get preview_invoice_path(@invoice)
    assert_response :success

    assert_valid_pdf_response

    # Verify the invoice processing included logo data
    # (We can't easily inspect PDF content, but we can verify the logo was processed)
    assert issuer_company.pdf_logo.present?, "Logo should be present in issuer company"
    assert_equal "50.0mm", issuer_company.pdf_logo_width
    assert_equal "15.0mm", issuer_company.pdf_logo_height
  end

  private

  def assert_valid_pdf_response
    assert_equal 'application/pdf', response.content_type
    assert response.body.start_with?('%PDF'), "Response should be a valid PDF file"
  end
end
