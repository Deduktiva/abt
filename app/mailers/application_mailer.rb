class ApplicationMailer < ActionMailer::Base
  def initialize
    super()
    setup_issuer
  end

  default :from => Proc.new { build_default_from }
  layout 'mailer'

  protected

  def setup_issuer
    @issuer = IssuerCompany.get_the_issuer!
  end

  def build_default_from
    "\"#{@issuer.short_name}\" <#{@issuer.document_email_from}>"
  end

  # Send the standard document email envelope. From comes from the default
  # configured at class level, bcc from the issuer. No-op when `to` is blank.
  def document_mail(to:, subject:, cc: nil)
    return if to.blank?
    mail(
      to: to,
      cc: cc,
      bcc: @issuer.document_email_auto_bcc,
      subject: subject
    )
  end

  # Strip CR/LF from values interpolated into mail headers (e.g. Subject) to
  # prevent header injection. The mail gem strips CRLF too, but doing it
  # explicitly keeps us safe if that ever changes.
  def sanitize_header_value(value)
    value.to_s.gsub(/[\r\n]+/, ' ')
  end
end
