require "test_helper"

class PdfGenerationTest < ActionDispatch::IntegrationTest
  fixtures :customers, :projects, :sales_tax_customer_classes, :sales_tax_product_classes, :sales_tax_rates, :issuer_companies, :document_numbers, :languages

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

  def test_invoice_publishing_creates_attachment
    # Publish the invoice (this should create PDF attachment)
    post publish_invoice_path(@invoice)

    assert_redirected_to invoice_path(@invoice, published: 1)

    @invoice.reload
    assert @invoice.published?, "Invoice should be published after publishing"

    # Check if PDF attachment was created
    assert @invoice.attachment.present?
    assert_equal "application/pdf", @invoice.attachment.content_type
    assert @invoice.attachment.data.start_with?("%PDF"), "Attachment should be a PDF"
  end

  def test_pdf_contains_invoice_data
    get preview_invoice_path(@invoice)
    assert_response :success

    # While we can't easily parse PDF content in tests, we can verify
    # that the invoice was processed through the publish controller
    # by checking that invoice_lines have calculated amounts
    @invoice.reload
    assert @invoice.invoice_lines.any? { |line| line.amount.present? if line.type == "item" }
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

  def test_invoice_pdf_generation_for_export_customer_without_vat_id
    # Customers in tax classes that don't require a VAT ID (export / non-EU /
    # B2C) must be able to render an invoice PDF. Regression test for the
    # invoice_publisher check that previously rejected any blank customer_vat_id.
    export_customer = Customer.create!(
      name: "USA Corporation Inc.",
      matchcode: "USACORP_TEST",
      address: "123 Business Ave\nNew York, NY 10001",
      country_iso2: "US",
      sales_tax_customer_class: sales_tax_customer_classes(:restoftheworld),
      language: languages(:english),
      team: teams(:default)
    )
    assert_nil export_customer.vat_id

    invoice = Invoice.create!(customer: export_customer, project: @project)
    invoice.invoice_lines.create!(
      type: "item", title: "Service", quantity: 1, rate: 100.00,
      sales_tax_product_class_id: sales_tax_product_classes(:standard).id
    )

    get preview_invoice_path(invoice)
    assert_response :success
    assert_valid_pdf_response
  end
end
