require "builder"

# Apache FOP wrapper.
#
# Security assumptions (issue #273):
# - Callers MUST emit XML via Builder::XmlMarkup (or another escaping
#   serializer). Unescaped user input would let an attacker inject XML
#   markup including a DOCTYPE.
# - DOCTYPE rejection is enforced JVM-wide by bin/abt-fop via
#   -Djdk.xml.dtd.support=deny (plus belt-and-suspenders JAXP properties).
# - <fo:external-graphic> can still fetch arbitrary file:// / http:// URIs
#   if the FO template ever embeds an untrusted URI. The renderers only
#   embed a server-controlled tempfile path (logo_file_path) from
#   render_pdf_with_logo, so this surface is not currently reachable.
class FopRenderer
  def initialize
    @rails_tmp = Rails.root.join("tmp")
    @template_path = Rails.root.join("lib", "foptemplate")
    @fop_conf = @template_path.join("fop-conf.xml")
    # Pin the font cache to tmp/. Otherwise FOP writes it relative to
    # <base>.</base> in fop-conf.xml, which resolves to the cwd we set when
    # spawning FOP (lib/foptemplate/, via the chdir: option in
    # execute_fop_command), leaving an untracked .fop/ directory in the
    # source tree after every render.
    @fop_cache = @rails_tmp.join("fop-fonts.cache")
  end

  def render_pdf_with_logo(xsl_template, logo_data = nil)
    tpl_xsl = @template_path.join(xsl_template)

    # Resolve FOP binary path, can be relative
    fop_binary = resolve_fop_binary_path

    # Dedicated owner-only temp dir. The input XML carries customer data and
    # the payment token, and the output PDF is attached/emailed verbatim, so
    # no other local OS user may read or substitute these files. FOP always
    # runs as this same uid (native bin/abt-fop directly; bin/abt-fop-container
    # via -u "$(id -u):$(id -g)" + podman --userns=keep-id), so 0700/0600
    # suffices everywhere — group/other bits would only widen exposure.
    Dir.mktmpdir("abt-fop-", @rails_tmp) do |temp_dir|
      File.chmod(0700, temp_dir)

      logo_path = nil
      if logo_data
        logo_path = File.join(temp_dir, "logo.pdf")
        write_file_with_permissions(logo_path, logo_data, 0600, binary: true)
      end

      # Call block to emit XML
      xml_data = yield logo_path

      xml_path = File.join(temp_dir, "input.xml")
      write_file_with_permissions(xml_path, xml_data, 0600)

      Rails.logger.info "FopRenderer wrote XML to: #{xml_path}"
      Rails.logger.debug File.read(xml_path)

      execute_fop_command(fop_binary, xml_path, tpl_xsl, temp_dir)
    end
  end

  private

  def resolve_fop_binary_path
    if Settings.fop.binary_path.start_with?("/")
      Settings.fop.binary_path
    else
      Rails.root.join(Settings.fop.binary_path).to_s
    end
  end

  def execute_fop_command(fop_binary, xml_path, xsl_path, temp_dir)
    begin
      pdf_path = File.join(temp_dir, "output.pdf")

      # Pre-create the output file owner-only; FOP (same uid) overwrites it.
      write_file_with_permissions(pdf_path, "", 0600)

      fop_command = build_fop_command(fop_binary, xml_path, xsl_path, pdf_path)

      fop_result, exit_status = run_fop(fop_command)

      Rails.logger.debug "fop result: #{fop_result}"
      Rails.logger.debug "fop exit status: #{exit_status}"

      # Check FOP exit code first
      if exit_status != 0
        raise "fop failed with exit code #{exit_status}:\n#{fop_result}"
      end

      # In test environment, also output FOP errors to expose hidden failures
      if Rails.env.test? && fop_result.include?("SEVERE")
        puts "FOP ERROR OUTPUT: #{fop_result}"
      end

      begin
        pdf_content = File.read(pdf_path)
        if pdf_content.empty?
          raise "fop generated empty PDF file:\n#{fop_result}"
        end

        # Validate PDF has proper trailer
        if !pdf_content.end_with?("%%EOF") && !pdf_content.end_with?("%%EOF\n")
          raise "fop generated invalid PDF (missing %%EOF trailer, got #{pdf_content.length} bytes):\n#{fop_result}"
        end

        pdf_content
      rescue Errno::ENOENT
        raise "fop failed - no output file created:\n#{fop_result}"
      end
    rescue
      Rails.logger.error "fop failed: #{$!}"
      raise
    end
  end

  # Spawn FOP and return [combined stdout/stderr, exit status].
  # Array form (no shell): each argument is passed verbatim to FOP, so a
  # path containing shell metacharacters can't be interpreted as a command.
  # chdir runs FOP with cwd at the template dir, which fop-conf.xml's
  # relative <base> requires.
  def run_fop(fop_command)
    Rails.logger.debug "Calling fop: #{fop_command.inspect}"

    fop_result = nil
    exit_status = nil
    IO.popen(fop_command, "r", err: [ :child, :out ], chdir: @template_path.to_s) do |fop_io|
      fop_result = fop_io.read
      fop_io.close
      exit_status = $?.exitstatus
    end
    [ fop_result, exit_status ]
  end

  # Returns an argv array for IO.popen; cwd is set via the popen chdir:
  # option, so no shell is involved.
  def build_fop_command(fop_binary, xml_path, xsl_path, pdf_path)
    [
      fop_binary.to_s,
      "-xml", xml_path.to_s,
      "-xsl", xsl_path.to_s,
      "-pdf", pdf_path.to_s,
      "-c", @fop_conf.to_s,
      "-cache", @fop_cache.to_s
    ]
  end

  # Write a file and chmod it explicitly, so the mode is exactly `permissions`
  # regardless of the process umask (a strict umask must not further restrict
  # FOP's access; a loose one must not widen it).
  def write_file_with_permissions(path, content, permissions, binary: false)
    if binary
      File.binwrite(path, content)
    else
      File.write(path, content)
    end
    File.chmod(permissions, path)
  end
end
