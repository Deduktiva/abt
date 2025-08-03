require "test_helper"

class FopInstallationTest < ActiveSupport::TestCase
  def test_fop_binary_exists
    fop_path = Settings.fop&.binary_path
    skip "FOP binary not configured" unless fop_path
    
    assert File.exist?(fop_path), "FOP binary not found at #{fop_path}"
    assert File.executable?(fop_path), "FOP binary is not executable at #{fop_path}"
  end

  def test_fop_version_compatibility
    fop_path = Settings.fop&.binary_path
    skip "FOP binary not configured" unless fop_path

    # Run fop -version to check version
    result = `"#{fop_path}" -version 2>&1`
    assert $?.success?, "FOP version check failed: #{result}"
    
    # Check for minimum FOP version (2.0+)
    # Handle both "FOP Version X.Y" and Debian package format "fop X.Y+dfsg-Z"
    version_match = result.match(/(?:FOP Version|fop)\s+(\d+\.\d+)/i)
    assert version_match, "Could not parse FOP version from: #{result}"
    
    version = version_match[1].to_f
    assert version >= 2.0, "FOP version #{version} is too old. Minimum required: 2.0"
  end

  def test_fop_saxon_support
    fop_path = Settings.fop&.binary_path
    skip "FOP binary not configured" unless fop_path

    # Create a simple test XML to verify Saxon XSLT 2.0 support
    test_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <test>Hello World</test>
    XML
    
    test_xsl = <<~XSL
      <?xml version="1.0" encoding="UTF-8"?>
      <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <xsl:output method="text"/>
        <xsl:template match="/test">
          <xsl:value-of select="upper-case(.)"/>
        </xsl:template>
      </xsl:stylesheet>
    XSL
    
    Dir.mktmpdir do |tmpdir|
      xml_file = File.join(tmpdir, "test.xml")
      xsl_file = File.join(tmpdir, "test.xsl")
      
      File.write(xml_file, test_xml)
      File.write(xsl_file, test_xsl)
      
      # Test XSLT 2.0 function (upper-case) which requires Saxon
      if fop_path.include?('bin/fop') && File.read(fop_path).include?('podman')
        # Podman-based FOP already includes Saxon
        result = `"#{fop_path}" -xml "#{xml_file}" -xsl "#{xsl_file}" -foout /dev/null 2>&1`
      else
        # System FOP with Saxon Java system property
        result = `JAVA_OPTS='-Djavax.xml.transform.TransformerFactory=net.sf.saxon.TransformerFactoryImpl' "#{fop_path}" -xml "#{xml_file}" -xsl "#{xsl_file}" -foout /dev/null 2>&1`
      end
      
      refute result.include?("ClassNotFoundException"), "Saxon XSLT processor not found: #{result}"
      refute result.include?("upper-case"), "XSLT 2.0 functions not working. Saxon may not be properly configured: #{result}"
    end
  end
end
