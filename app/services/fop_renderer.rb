require 'builder'

class FopRenderer

  def initialize
    @rails_tmp = Rails.root.join('tmp')
    @template_path = Rails.root.join('lib', 'foptemplate')
    @fop_conf = @template_path.join('fop-conf.xml')
  end

  def render_pdf_with_logo(logo_data = nil, xsl_template = 'invoice.xsl')
    tpl_xsl = @template_path.join(xsl_template)

    # Resolve FOP binary path, can be relative
    fop_binary = resolve_fop_binary_path

    Tempfile.create(['logo', '.pdf'], @rails_tmp) do |logo_file|
      if logo_data
        logo_file.binmode
        logo_file.write(logo_data)
        logo_file.close

        # Generate XML with actual logo path
        xml_data = yield logo_file.path
      else
        xml_data = yield nil
      end

      Tempfile.create('abt-xml', @rails_tmp) do |xml_file|
        xml_file.write(xml_data)
        xml_file.flush

        Rails.logger.info "FopRenderer wrote XML to: #{xml_file.path}"
        Rails.logger.debug File.read(xml_file.path)

        execute_fop_command(fop_binary, xml_file.path, tpl_xsl)
      end
    end
  end

  private

  def resolve_fop_binary_path
    if Settings.fop.binary_path.start_with?('/')
      Settings.fop.binary_path
    else
      Rails.root.join(Settings.fop.binary_path).to_s
    end
  end

  def execute_fop_command(fop_binary, xml_path, xsl_path)
    begin
      pdffile = Tempfile.new('abt-pdf', @rails_tmp)
      pdffile.close

      fop_command = build_fop_command(fop_binary, xml_path, xsl_path, pdffile.path)

      Rails.logger.debug "Calling fop: #{fop_command}"

      fop_result = nil
      IO.popen(fop_command, mode="r", :err=>[:child, :out]) do |fop_io|
        fop_result = fop_io.read
      end
      Rails.logger.debug "fop result: #{fop_result}"

      begin
        return File.read(pdffile.path)
      rescue Errno::ENOENT
        raise "fop failed:\n#{fop_result}"
      end
    rescue
      Rails.logger.error "fop failed: #{$!}"
      raise
    ensure
      pdffile.close! if pdffile
    end
  end

  def build_fop_command(fop_binary, xml_path, xsl_path, pdf_path)
    "cd \"#{@template_path}\" && " +
    "\"#{fop_binary}\" " +
    "-xml \"#{xml_path}\" -xsl \"#{xsl_path}\" -pdf \"#{pdf_path}\" -c \"#{@fop_conf}\""
  end
end
