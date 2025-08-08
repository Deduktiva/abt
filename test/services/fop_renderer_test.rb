require "test_helper"

class FopRendererTest < ActiveSupport::TestCase
  def test_fop_renderer_smoke_test
    # Test with more permissive umask for temp files
    old_umask = File.umask(0022)
    renderer = FopRenderer.new
    
    # Generate minimal XML content
    xml_content = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <fo:root xmlns:fo="http://www.w3.org/1999/XSL/Format">
        <fo:layout-master-set>
          <fo:simple-page-master master-name="simple" page-height="11in" page-width="8.5in">
            <fo:region-body margin="1in"/>
          </fo:simple-page-master>
        </fo:layout-master-set>
        <fo:page-sequence master-reference="simple">
          <fo:flow flow-name="xsl-region-body">
            <fo:block>Test FOP Integration</fo:block>
          </fo:flow>
        </fo:page-sequence>
      </fo:root>
    XML
    
    # Test PDF generation without logo
    pdf_data = renderer.render_pdf_with_logo(nil, 'invoice.xsl') do |logo_path|
      xml_content
    end
    
    # Verify PDF was generated
    assert_not_nil pdf_data
    
    # FOP is working if we get a valid PDF header (even if content is minimal)
    assert pdf_data.start_with?('%PDF'), "Should be a valid PDF file"
    assert pdf_data.length > 10, "PDF should have at least PDF header (got #{pdf_data.length} bytes)"
  rescue => e
    # Capture detailed error information for debugging
    flunk "FOP rendering failed: #{e.message}\n#{e.backtrace.join("\n")}"
  ensure
    # Restore original umask
    File.umask(old_umask) if old_umask
  end
end