# Preview all emails at http://localhost:3000/rails/mailers/invoice_mailer
class InvoiceMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/invoice_mailer/customer_email
  def customer_email
    InvoiceMailer.with(invoice: Invoice.first).customer_email
  end
end
