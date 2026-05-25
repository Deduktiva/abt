class InvoiceMailer < ApplicationMailer
  def customer_email
    @invoice = params[:invoice]
    attachments[@invoice.attachment.filename] = {
      mime_type: @invoice.attachment.content_type,
      content: @invoice.attachment.data
    }

    customer = @invoice.customer
    to = cc = subject = nil

    with_customer_locale(customer) do
      if customer.invoice_email_auto_enabled
        subject = customer.invoice_email_auto_subject_template
                          .gsub("$CUST_ORDER$", sanitize_header_value(@invoice.cust_order))
                          .gsub("$CUST_REF$", sanitize_header_value(@invoice.cust_reference))
        to = customer.invoice_email_auto_to
        cc = customer.email if customer.email.present? && customer.email != to
      elsif customer.email.present?
        subject = I18n.t("mailers.invoice.subject", issuer_name: @issuer.short_name, document_number: @invoice.document_number)
        to = customer.email
      end

      document_mail(to: to, cc: cc, subject: subject)
    end
  end
end
