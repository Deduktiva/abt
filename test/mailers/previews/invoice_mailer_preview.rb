# Preview all emails at http://localhost:3000/rails/mailers/invoice_mailer
class InvoiceMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/invoice_mailer/customer_email
  def customer_email
    invoice_id = params[:invoice_id] || Invoice.first&.id
    invoice = Invoice.find(invoice_id) if invoice_id

    if invoice
      InvoiceMailer.with(invoice: invoice).customer_email
    else
      # Fallback if no invoices exist
      raise "No invoices found. Please create an invoice first."
    end
  end
end
