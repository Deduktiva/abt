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
end
