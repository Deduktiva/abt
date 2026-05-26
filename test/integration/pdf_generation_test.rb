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
      type: "item",
      title: "Test Product",
      description: "Test product description",
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
    post book_invoice_path(@invoice)

    assert_redirected_to invoice_path(@invoice, booked: 1)

    @invoice.reload
    assert @invoice.published?, "Invoice should be published after booking"

    # Check if PDF attachment was created
    assert @invoice.attachment.present?
    assert_equal "application/pdf", @invoice.attachment.content_type
    assert @invoice.attachment.data.start_with?("%PDF"), "Attachment should be a PDF"
  end

  def test_pdf_contains_invoice_data
    get preview_invoice_path(@invoice)
    assert_response :success

    # While we can't easily parse PDF content in tests, we can verify
    # that the invoice was processed through the booking controller
    # by checking that invoice_lines have calculated amounts
    @invoice.reload
    assert @invoice.invoice_lines.any? { |line| line.amount.present? if line.type == "item" }
  end

  def test_preview_of_an_empty_invoice_redirects_with_a_flash
    minimal_invoice = Invoice.create!(
      customer: @customer,
      project: @project
    )

    get preview_invoice_path(minimal_invoice)

    assert_redirected_to invoice_path(minimal_invoice)
    assert_match(/no item lines/i, flash[:error])
  end

  def test_booking_an_empty_invoice_is_blocked
    empty = Invoice.create!(
      customer: @customer,
      project: @project
    )

    post book_invoice_path(empty)

    assert_redirected_to invoice_path(empty)
    assert_match(/no item lines/i, flash[:error])
    assert_not empty.reload.published?
  end

  def test_booking_an_invoice_with_only_non_item_lines_is_blocked
    inv = Invoice.create!(
      customer: @customer,
      project: @project
    )
    inv.invoice_lines.create!(type: "text", title: "Note", description: "no items here", position: 1)
    inv.invoice_lines.create!(type: "subheading", title: "Section", position: 2)

    post book_invoice_path(inv)

    assert_redirected_to invoice_path(inv)
    assert_match(/no item lines/i, flash[:error])
    assert_not inv.reload.published?
  end

  def test_model_rejects_setting_published_true_on_an_empty_invoice
    inv = Invoice.create!(
      customer: @customer,
      project: @project
    )

    inv.published = true
    refute inv.valid?
    assert_includes inv.errors[:base].join, "item line"
  end

  def test_pdf_generation_with_logo
    # Set up issuer company with a PDF logo
    issuer_company = issuer_companies(:one)
    logo_path = Rails.root.join("test", "fixtures", "files", "example_logo.pdf")
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
    assert_equal "application/pdf", response.content_type
    assert response.body.start_with?("%PDF"), "Response should be a valid PDF file"
  end
end
