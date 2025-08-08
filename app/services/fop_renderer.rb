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

    # Create dedicated temp directory with proper permissions
    Dir.mktmpdir('abt-fop-', @rails_tmp) do |temp_dir|
      File.chmod(0755, temp_dir)
      
      logo_path = nil
      if logo_data
        logo_path = File.join(temp_dir, 'logo.pdf')
        write_file_with_permissions(logo_path, logo_data, 0644, binary: true)
      end

      # Generate XML with logo path
      xml_data = yield logo_path

      xml_path = File.join(temp_dir, 'input.xml')
      write_file_with_permissions(xml_path, xml_data, 0644)

      Rails.logger.info "FopRenderer wrote XML to: #{xml_path}"
      Rails.logger.debug File.read(xml_path)

      execute_fop_command(fop_binary, xml_path, tpl_xsl, temp_dir)
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

  def execute_fop_command(fop_binary, xml_path, xsl_path, temp_dir)
    begin
      pdf_path = File.join(temp_dir, 'output.pdf')
      
      # Create empty output file with correct permissions that FOP can write to
      write_file_with_permissions(pdf_path, '', 0666)
      
      fop_command = build_fop_command(fop_binary, xml_path, xsl_path, pdf_path)

      Rails.logger.debug "Calling fop: #{fop_command}"

      fop_result = nil
      IO.popen(fop_command, mode="r", :err=>[:child, :out]) do |fop_io|
        fop_result = fop_io.read
      end
      Rails.logger.debug "fop result: #{fop_result}"

      begin
        pdf_content = File.read(pdf_path)
        if pdf_content.empty?
          raise "fop generated empty PDF file:\n#{fop_result}"
        end
        return pdf_content
      rescue Errno::ENOENT
        raise "fop failed - no output file created:\n#{fop_result}"
      end
    rescue
      Rails.logger.error "fop failed: #{$!}"
      raise
    end
  end

  def build_fop_command(fop_binary, xml_path, xsl_path, pdf_path)
    "cd \"#{@template_path}\" && " +
    "\"#{fop_binary}\" " +
    "-xml \"#{xml_path}\" -xsl \"#{xsl_path}\" -pdf \"#{pdf_path}\" -c \"#{@fop_conf}\""
  end

  # Write file with explicit permissions to work around restrictive umask
  # This ensures FOP can access the files regardless of process umask setting
  def write_file_with_permissions(path, content, permissions, binary: false)
    if binary
      File.binwrite(path, content)
    else
      File.write(path, content)
    end
    File.chmod(permissions, path)
  end
end
