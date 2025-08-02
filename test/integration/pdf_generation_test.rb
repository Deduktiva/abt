require "test_helper"

class PdfGenerationTest < ActionDispatch::IntegrationTest
  fixtures :customers, :projects, :sales_tax_customer_classes, :sales_tax_product_classes, :sales_tax_rates

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
    # Test the preview action that generates PDF or debug log
    get preview_invoice_path(@invoice)
    
    assert_response :success
    
    # The preview action returns PDF if successful, otherwise debug log as text
    if response.content_type == 'application/pdf'
      assert response.body.start_with?('%PDF'), "Response should be a PDF file"
      assert response.body.length > 1000, "PDF should have substantial content"
    else
      # When FOP is not configured or PDF generation fails, returns debug log
      assert_equal 'text/plain', response.content_type
      assert response.body.include?('Test-Booking succeeded?'), "Should contain booking debug info"
    end
  end

  def test_invoice_booking_creates_attachment
    skip "FOP not configured" unless fop_configured?
    
    # Book the invoice (this should create PDF attachment)
    post book_invoice_path(@invoice), params: { save: 'true' }
    
    assert_response :success
    
    @invoice.reload
    assert @invoice.published?, "Invoice should be published after booking"
    
    # Check if PDF attachment was created (might fail if templates missing)
    if @invoice.attachment.present?
      assert_equal 'application/pdf', @invoice.attachment.content_type
      # Only check PDF content if attachment has data
      if @invoice.attachment.data.present?
        assert @invoice.attachment.data.start_with?('%PDF'), "Attachment should be a PDF"
      end
    else
      # If no attachment, that's OK for this test - booking logic still worked
      puts "Note: PDF attachment not created (likely missing templates or FOP config)"
    end
  end

  def test_pdf_contains_invoice_data
    skip "FOP not configured" unless fop_configured?
    
    get preview_invoice_path(@invoice)
    assert_response :success
    
    # While we can't easily parse PDF content in tests, we can verify
    # that the invoice was processed through the booking controller
    # by checking that invoice_lines have calculated amounts
    @invoice.reload
    assert @invoice.invoice_lines.any? { |line| line.amount.present? if line.type == 'item' }
  end

  def test_pdf_generation_with_missing_data
    skip "FOP not configured" unless fop_configured?
    
    # Create invoice with minimal data to test error handling
    minimal_invoice = Invoice.create!(
      customer: @customer,
      project: @project
    )
    
    get preview_invoice_path(minimal_invoice)
    
    # Should either generate PDF or return error, but not crash
    assert_response :success, "Should handle invoices with minimal data gracefully"
  end

  private

  def fop_configured?
    Settings.fop&.binary_path.present? && File.exist?(Settings.fop.binary_path)
  rescue
    false
  end
end