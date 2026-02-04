class InvoiceMailer < ApplicationMailer
  def customer_email
    @invoice = params[:invoice]
    @issuer = IssuerCompany.get_the_issuer!
    attachments[@invoice.attachment.filename] = {
      mime_type: @invoice.attachment.content_type,
      content: @invoice.attachment.data
    }

    # Set locale based on customer language
    I18n.with_locale(@invoice.customer.language.iso_code) do
      if @invoice.customer.invoice_email_auto_enabled
        subject = @invoice.customer.invoice_email_auto_subject_template.gsub('$CUST_ORDER$', @invoice.cust_order).gsub('$CUST_REF$', @invoice.cust_reference)
        to = @invoice.customer.invoice_email_auto_to
      else
        # Use customer contacts that should receive invoices for this project
        recipients = get_invoice_recipients(@invoice)
        if recipients.any?
          subject = I18n.t('mailers.invoice.subject', issuer_name: @issuer.short_name, document_number: @invoice.document_number)
          to = recipients
        else
          to = nil
        end
      end

      unless to.nil?
        mail(
          to: to,
          from: "\"#{@issuer.short_name}\" <#{@issuer.document_email_from}>",
          bcc: @issuer.document_email_auto_bcc,
          subject: subject
        )
      end
    end
  end

  private

  # Get email recipients for invoice delivery based on customer contacts
  # When adding new document types, create similar methods:
  # def get_quote_recipients(quote)
  #   quote.customer.customer_contacts
  #        .select { |contact| contact.receives_quotes_for_project?(quote.project) }
  #        .map(&:email)
  # end
  def get_invoice_recipients(invoice)
    invoice.customer.customer_contacts
           .select { |contact| contact.receives_invoices_for_project?(invoice.project) }
           .map(&:email)
  end
end
