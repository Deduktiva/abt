require 'test_helper'

class PdfTemplateTest < ActiveSupport::TestCase
  def setup
    @fop_template_dir = Rails.root.join('lib', 'foptemplate')
  end

  test "document base template exists and is valid XML" do
    base_template_path = @fop_template_dir.join('document_base.xsl')
    assert File.exist?(base_template_path), "document_base.xsl should exist"

    # Verify it's valid XML
    xml_content = File.read(base_template_path)
    assert_no_error { Nokogiri::XML(xml_content) { |config| config.strict } }
  end

  test "invoice template exists and imports base template" do
    invoice_template_path = @fop_template_dir.join('invoice.xsl')
    assert File.exist?(invoice_template_path), "invoice.xsl should exist"

    # Verify it imports the base template
    xml_content = File.read(invoice_template_path)
    assert_includes xml_content, 'href="document_base.xsl"', "Invoice template should import document_base.xsl"

    # Verify it's valid XML
    assert_no_error { Nokogiri::XML(xml_content) { |config| config.strict } }
  end

  test "original invoice template is preserved" do
    original_template_path = @fop_template_dir.join('invoice_original.xsl')
    assert File.exist?(original_template_path), "invoice_original.xsl should exist as backup"
  end

  test "base template contains reusable components" do
    base_template_path = @fop_template_dir.join('document_base.xsl')
    xml_content = File.read(base_template_path)

    # Check for reusable templates
    assert_includes xml_content, 'name="standard-page-masters"', "Should contain reusable page masters"
    assert_includes xml_content, 'name="sender-address-block"', "Should contain reusable sender address block"
    assert_includes xml_content, 'name="recipient-address-block"', "Should contain reusable recipient address block"
    assert_includes xml_content, 'name="company-header-block"', "Should contain reusable company header block"
    assert_includes xml_content, 'name="info-box"', "Should contain reusable info box template"
    assert_includes xml_content, 'name="pdf-metadata"', "Should contain reusable PDF metadata template"
  end

  test "invoice template contains invoice-specific elements" do
    invoice_template_path = @fop_template_dir.join('invoice.xsl')
    xml_content = File.read(invoice_template_path)

    # Check for invoice-specific templates
    assert_includes xml_content, 'match="/document/items/item"', "Should contain invoice line item template"
    assert_includes xml_content, 'match="/document/sums/tax-classes"', "Should contain tax class template"
    assert_includes xml_content, '<xsl:with-param name="document-type">Invoice</xsl:with-param>', "Should specify document type as Invoice"
  end

  private

  def assert_no_error
    yield
  rescue => e
    flunk "Expected no error, but got: #{e.class.name}: #{e.message}"
  end
end