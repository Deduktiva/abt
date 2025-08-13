class InvoiceMailer < ApplicationMailer
  def customer_email
    @invoice = params[:invoice]
    @issuer = IssuerCompany.get_the_issuer!
    attachments[@invoice.attachment.filename] = {
      mime_type: @invoice.attachment.content_type,
      content: @invoice.attachment.data
    }

    if @invoice.customer.invoice_email_auto_enabled
      subject = @invoice.customer.invoice_email_auto_subject_template.gsub('$CUST_ORDER$', @invoice.cust_order).gsub('$CUST_REF$', @invoice.cust_reference)
      to = @invoice.customer.invoice_email_auto_to
    elsif @invoice.customer.email
      subject = "#{@issuer.short_name} Invoice #{@invoice.document_number}"
      to = @invoice.customer.email
    else
      to = nil
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
