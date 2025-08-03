class InvoiceMailer < ApplicationMailer
  def customer_email
    @issuer = IssuerCompany.get_the_issuer!
    @invoice = params[:invoice]
    attachments[@invoice.attachment.filename] = {
      mime_type: @invoice.attachment.content_type,
      content: @invoice.attachment.data
    }

    if @invoice.customer.invoice_email_auto_enabled
      subject = @invoice.customer.invoice_email_auto_subject_template.gsub('$CUST_ORDER$', @invoice.cust_order).gsub('$CUST_REF$', @invoice.cust_reference)
      mail(
        to: @invoice.customer.invoice_email_auto_to,
        from: "\"#{@issuer.short_name}\" <#{@issuer.document_email_from}>",
        bcc: @issuer.document_email_auto_bcc,
        subject: subject
      )
    elsif @invoice.customer.email
      mail(
        to: @invoice.customer.email,
        from: "\"#{@issuer.short_name}\" <#{@issuer.document_email_from}>",
        bcc: @issuer.document_email_auto_bcc,
        subject: "#{@issuer.short_name} Invoice #{@invoice.document_number}"
      )
    end
  end
end
