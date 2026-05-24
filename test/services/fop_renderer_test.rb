require "test_helper"

class FopRendererTest < ActiveSupport::TestCase
  def test_fop_renderer_smoke_test
    # Test with more permissive umask for temp files
    old_umask = File.umask(0022)

    renderer = FopRenderer.new

    # Generate minimal FO content that will render successfully
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
            <fo:block font-family="OpenSans" font-size="12pt">
              Test FOP Integration - Hello World! This text ensures fonts are initialized.
            </fo:block>
            <fo:block font-family="OpenSans" font-size="10pt" margin-top="12pt" font-weight="bold">
              Second paragraph with different formatting to test font loading.
            </fo:block>
          </fo:flow>
        </fo:page-sequence>
      </fo:root>
    XML

    # Test PDF generation with simple XSL transformation (uses lib/foptemplate/simple_test.xsl)
    pdf_data = renderer.render_pdf_with_logo('simple_test.xsl') do |logo_path|
      xml_content
    end

    # Verify PDF was generated successfully
    assert_not_nil pdf_data
    assert pdf_data.start_with?('%PDF'), "Should be a valid PDF file"
    assert pdf_data.end_with?("%%EOF") || pdf_data.end_with?("%%EOF\n"), "PDF should have valid trailer"
    assert pdf_data.length > 1000, "PDF should have substantial content (got #{pdf_data.length} bytes)"
  rescue => e
    # Capture detailed error information for debugging
    flunk "FOP rendering failed: #{e.message}\n#{e.backtrace.join("\n")}"
  ensure
    # Restore original umask
    File.umask(old_umask) if old_umask
  end

  def test_fop_renderer_blocks_external_entity_expansion
    # Defense-in-depth (issue #273). The hardened FOP wrapper must reject any
    # XML containing a DOCTYPE — and therefore any external entity reference
    # — regardless of which JAXP layer enforces it (jdk.xml.dtd.support=deny,
    # accessExternalDTD, or Xerces' disallow-doctype-decl default).
    old_umask = File.umask(0022)

    # Place the bait file under Rails.root/tmp because production runs FOP in
    # a container with only the project root bind-mounted (script/setup-fop.sh).
    # A path under /tmp would not exist inside that container, so an
    # unhardened FOP would still fail to leak — which would make the test
    # pass for the wrong reason.
    secret_dir = Rails.root.join('tmp')
    secret_path = secret_dir.join("abt-xxe-secret-#{Process.pid}.txt").to_s
    File.write(secret_path, 'XXE_LEAKED_SECRET')
    File.chmod(0644, secret_path)

    xxe_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE fo:root [
        <!ENTITY xxe SYSTEM "file://#{secret_path}">
      ]>
      <fo:root xmlns:fo="http://www.w3.org/1999/XSL/Format">
        <fo:layout-master-set>
          <fo:simple-page-master master-name="simple" page-height="11in" page-width="8.5in">
            <fo:region-body margin="1in"/>
          </fo:simple-page-master>
        </fo:layout-master-set>
        <fo:page-sequence master-reference="simple">
          <fo:flow flow-name="xsl-region-body">
            <fo:block font-family="OpenSans" font-size="12pt">LEAK[&xxe;]LEAK</fo:block>
          </fo:flow>
        </fo:page-sequence>
      </fo:root>
    XML

    renderer = FopRenderer.new

    # We expect FOP to fail with an error mentioning DOCTYPE — that proves
    # the rejection actually fired in the parser, not that the bait file
    # was unreachable. Then we additionally refute the leak ever made it
    # into the error output.
    error = assert_raises(RuntimeError) do
      renderer.render_pdf_with_logo('simple_test.xsl') do |_logo_path|
        xxe_xml
      end
    end

    assert_match(/DOCTYPE.*(disallow|not allowed|denied)/i, error.message,
      "FOP must reject DOCTYPE-bearing input; got: #{error.message}")
    refute_includes error.message, 'XXE_LEAKED_SECRET',
      'External entity content must not leak into FOP error output'
  ensure
    File.delete(secret_path) if secret_path && File.exist?(secret_path)
    File.umask(old_umask) if old_umask
  end

  def test_fop_renderer_handles_invalid_data
    # Test with more permissive umask for temp files
    old_umask = File.umask(0022)

    renderer = FopRenderer.new

    # Generate invalid XML content that will cause FOP to fail
    invalid_xml_content = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <fo:root xmlns:fo="http://www.w3.org/1999/XSL/Format">
        <fo:layout-master-set>
          <fo:simple-page-master master-name="simple" page-height="11in" page-width="8.5in">
            <fo:region-body margin="1in"/>
          </fo:simple-page-master>
        </fo:layout-master-set>
        <fo:page-sequence master-reference="simple">
          <fo:flow flow-name="xsl-region-body">
            <!-- Invalid: table without required table-body -->
            <fo:table>
              <fo:table-column column-width="2in"/>
            </fo:table>
          </fo:flow>
        </fo:page-sequence>
      </fo:root>
    XML

    # Test that FOP properly detects and reports the error (uses lib/foptemplate/simple_test_invalid.xsl)
    error = assert_raises(RuntimeError) do
      renderer.render_pdf_with_logo('simple_test_invalid.xsl') do |logo_path|
        invalid_xml_content
      end
    end

    # Verify the error message contains FOP failure information
    assert_match(/fop failed with exit code 1/, error.message)
    assert_match(/ValidationException.*table.*missing child elements/, error.message)
  ensure
    # Restore original umask
    File.umask(old_umask) if old_umask
  end
end
