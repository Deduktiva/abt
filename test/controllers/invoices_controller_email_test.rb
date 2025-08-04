require 'test_helper'

class InvoicesControllerEmailTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
  end

  test "send_email delivers email for published invoice with regular customer email" do
    invoice = invoices(:published_invoice)

    assert_enqueued_jobs 1, only: InvoiceEmailSenderJob do
      post send_email_invoice_path(invoice)
    end

    assert_redirected_to invoice
    assert_equal 'E-Mail queued for sending.', flash[:notice]

    # Process the enqueued job to actually send the email
    perform_enqueued_jobs

    # Check that email was delivered and timestamp was set
    assert_equal 1, ActionMailer::Base.deliveries.size
    delivered_mail = ActionMailer::Base.deliveries.last
    assert_equal ["customer@good-company.co.uk"], delivered_mail.to
    assert_equal "My Example Invoice INV-2024-001", delivered_mail.subject

    # Check that email_sent_at was updated
    invoice.reload
    assert_not_nil invoice.email_sent_at
  end

  test "send_email delivers email for published invoice with auto email configuration" do
    invoice = invoices(:auto_email_invoice)

    assert_enqueued_jobs 1, only: InvoiceEmailSenderJob do
      post send_email_invoice_path(invoice)
    end

    assert_redirected_to invoice
    assert_equal 'E-Mail queued for sending.', flash[:notice]

    # Process the enqueued job to actually send the email
    perform_enqueued_jobs

    # Check that email was delivered and timestamp was set
    assert_equal 1, ActionMailer::Base.deliveries.size
    delivered_mail = ActionMailer::Base.deliveries.last
    assert_equal ["billing@autoemail.com"], delivered_mail.to
    assert_equal "Invoice AUTO-ORDER-111 - Ref: AUTO-REF-999", delivered_mail.subject

    # Check that email_sent_at was updated
    invoice.reload
    assert_not_nil invoice.email_sent_at
  end

  test "send_email handles customer without email gracefully" do
    invoice = invoices(:no_email_invoice)

    # Should still enqueue the job even if no email will be sent
    assert_enqueued_jobs 1, only: InvoiceEmailSenderJob do
      post send_email_invoice_path(invoice)
    end

    assert_redirected_to invoice
    assert_equal 'E-Mail queued for sending.', flash[:notice]

    # Process the enqueued job
    perform_enqueued_jobs

    # No email should be delivered for customer without email
    # The mailer returns NullMail which doesn't get delivered
    assert_equal 0, ActionMailer::Base.deliveries.size

    # But email_sent_at should still be set (job completed successfully)
    invoice.reload
    assert_not_nil invoice.email_sent_at
  end

  test "send_email only works for published invoices" do
    invoice = invoices(:draft_invoice)

    post send_email_invoice_path(invoice)

    assert_redirected_to invoice
    assert_equal 'Draft invoices can not be used for this action.', flash[:error]

    # No email should be sent
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "send_email includes PDF attachment" do
    invoice = invoices(:published_invoice)

    post send_email_invoice_path(invoice)
    perform_enqueued_jobs

    assert_equal 1, ActionMailer::Base.deliveries.size
    delivered_mail = ActionMailer::Base.deliveries.last
    assert_equal 1, delivered_mail.attachments.size

    attachment = delivered_mail.attachments.first
    assert_equal "test_invoice.pdf", attachment.filename
    assert_equal "application/pdf", attachment.content_type
  end

  test "send_email button only appears for published invoices with attachments" do
    # Test published invoice with attachment - button should appear
    published_invoice = invoices(:published_invoice)
    get invoice_path(published_invoice)
    assert_response :success
    assert_select 'button[data-action*="email-preview#open"]'

    # Test draft invoice - button should not appear
    draft_invoice = invoices(:draft_invoice)
    get invoice_path(draft_invoice)
    assert_response :success
    assert_select 'button[data-action*="email-preview#open"]', count: 0
  end

  test "send_email JSON response returns valid HTTP status" do
    invoice = invoices(:published_invoice)

    assert_enqueued_jobs 1, only: InvoiceEmailSenderJob do
      post send_email_invoice_path(invoice), headers: { 'Accept' => 'application/json' }
    end

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_equal invoice.id, json_response['id']
  end

  test "bulk_send_emails queues jobs for selected invoices" do
    invoice1 = invoices(:published_invoice)
    invoice2 = invoices(:auto_email_invoice)

    assert_enqueued_jobs 2, only: InvoiceEmailSenderJob do
      post bulk_send_emails_invoices_path, params: { invoice_ids: [invoice1.id, invoice2.id] }
    end

    assert_redirected_to invoices_path
    assert_equal '2 emails queued for sending.', flash[:notice]
  end

  test "bulk_send_emails handles empty selection" do
    post bulk_send_emails_invoices_path, params: { invoice_ids: [] }

    assert_redirected_to invoices_path
    assert_equal 'No invoices selected.', flash[:alert]
  end

  test "index filters invoices by email status" do
    # Test unsent filter
    get invoices_path(email_filter: 'unsent')
    assert_response :success
    assert_select 'li.page-item.active', text: 'Unsent'
  end

  test "unsent filter shows bulk send form" do
    get invoices_path(email_filter: 'unsent')
    assert_response :success
    assert_select 'form#bulk-email-form'
    assert_select 'input[type="submit"][value="Send Selected Emails"]'
  end
end
