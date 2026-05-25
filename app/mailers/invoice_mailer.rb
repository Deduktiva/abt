class InvoiceMailer < ApplicationMailer
  def customer_email
    @invoice = params[:invoice]
    attachments[@invoice.attachment.filename] = {
      mime_type: @invoice.attachment.content_type,
      content: @invoice.attachment.data
    }

    customer = @invoice.customer
    to = @invoice.email_recipients
    cc = @invoice.email_cc_recipients

    with_customer_locale(customer) do
      @salutation = @invoice.email_salutation_contact&.salutation_line.presence

      if customer.invoice_email_auto_enabled
        subject = customer.invoice_email_auto_subject_template
                          .gsub("$CUST_ORDER$", sanitize_header_value(@invoice.cust_order))
                          .gsub("$CUST_REF$", sanitize_header_value(@invoice.cust_reference))
      else
        subject = I18n.t("mailers.invoice.subject",
                         issuer_name: sanitize_header_value(@issuer.short_name),
                         document_number: sanitize_header_value(@invoice.document_number))
      end

      document_mail(to: to, cc: cc, subject: subject)
    end
  end
end
