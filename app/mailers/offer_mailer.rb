class OfferMailer < ApplicationMailer
  def customer_email
    @offer = params[:offer]
    @version = @offer.current_sent_version

    unless params[:skip_attachments]
      if (pdf = @version&.attachment)
        attachments[pdf.filename] = { mime_type: pdf.safe_content_type, content: pdf.data }
      end
    end

    customer = @offer.customer
    to = @offer.email_recipients

    with_customer_locale(customer) do
      @salutation = @version&.salutation_override.presence ||
                    @offer.email_salutation_contact&.salutation_line.presence

      subject = I18n.t("mailers.offer.subject",
                       issuer_name: sanitize_header_value(@issuer.short_name),
                       document_number: sanitize_header_value(@offer.document_number))
      document_mail(to: to, subject: subject)
    end
  end
end
