require "test_helper"

class InvoiceLanguageTest < ActionDispatch::IntegrationTest
  fixtures :customers, :projects, :sales_tax_customer_classes, :sales_tax_product_classes, :sales_tax_rates, :issuer_companies, :document_numbers, :languages

  def setup
    @project = projects(:test_project)
  end

  def test_pdf_generation_with_english_language
    # Create customer with English language
    english_customer = Customer.create!(
      name: "English Customer Ltd",
      matchcode: "ENG",
      address: "123 English Street\nLondon, UK",
      vat_id: "EN123456789",
      sales_tax_customer_class: sales_tax_customer_classes(:national),
      language: languages(:english)
    )

    english_invoice = Invoice.create!(
      customer: english_customer,
      project: @project,
      cust_reference: "ENG-REF",
      prelude: "Test invoice in English"
    )

    english_invoice.invoice_lines.create!(
      type: 'item',
      title: 'English Product',
      quantity: 1,
      rate: 100.00,
      sales_tax_product_class_id: sales_tax_product_classes(:standard).id
    )

    get preview_invoice_path(english_invoice)
    assert_response :success
    assert_equal 'application/pdf', response.content_type
    assert_valid_pdf_response
  end

  def test_pdf_generation_with_german_language
    # Create customer with German language
    german_customer = Customer.create!(
      name: "Deutsche Firma GmbH",
      matchcode: "DEU",
      address: "Musterstraße 123\n12345 Berlin, Deutschland",
      vat_id: "DE987654321",
      sales_tax_customer_class: sales_tax_customer_classes(:national),
      language: languages(:german)
    )

    german_invoice = Invoice.create!(
      customer: german_customer,
      project: @project,
      cust_reference: "DEU-REF",
      prelude: "Test-Rechnung auf Deutsch"
    )

    german_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Deutsches Produkt',
      quantity: 1,
      rate: 100.00,
      sales_tax_product_class_id: sales_tax_product_classes(:standard).id
    )

    get preview_invoice_path(german_invoice)
    assert_response :success
    assert_equal 'application/pdf', response.content_type
    assert_valid_pdf_response
  end

  def test_pdf_language_switching_regression
    # Test both languages sequentially to ensure no state pollution
    english_customer = Customer.create!(
      name: "English Customer", matchcode: "ENG1", address: "English Address",
      vat_id: "EN111111111",
      sales_tax_customer_class: sales_tax_customer_classes(:national),
      language: languages(:english)
    )

    german_customer = Customer.create!(
      name: "German Customer", matchcode: "GER1", address: "German Address",
      vat_id: "DE222222222",
      sales_tax_customer_class: sales_tax_customer_classes(:national),
      language: languages(:german)
    )

    english_invoice = Invoice.create!(customer: english_customer, project: @project)
    english_invoice.invoice_lines.create!(
      type: 'item', title: 'Test Item', quantity: 1, rate: 50.00,
      sales_tax_product_class_id: sales_tax_product_classes(:standard).id
    )

    german_invoice = Invoice.create!(customer: german_customer, project: @project)
    german_invoice.invoice_lines.create!(
      type: 'item', title: 'Test Item', quantity: 1, rate: 50.00,
      sales_tax_product_class_id: sales_tax_product_classes(:standard).id
    )

    # Generate English PDF
    get preview_invoice_path(english_invoice)
    assert_response :success
    assert_valid_pdf_response

    # Generate German PDF
    get preview_invoice_path(german_invoice)
    assert_response :success
    assert_valid_pdf_response
  end

  def test_customer_language_assignment_defaults_to_english
    customer = Customer.create!(
      name: "Test Customer",
      matchcode: "TEST",
      address: "Test Address",
      sales_tax_customer_class: sales_tax_customer_classes(:national)
    )

    assert_equal languages(:english), customer.language
  end

  def test_customer_language_can_be_changed
    customer = customers(:good_eu)
    assert_equal languages(:english), customer.language

    customer.update!(language: languages(:german))
    assert_equal languages(:german), customer.language
  end

  private

  def assert_valid_pdf_response
    assert_equal 'application/pdf', response.content_type
    assert response.body.start_with?('%PDF'), "Response should be a valid PDF file"
  end
end
