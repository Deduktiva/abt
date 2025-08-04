require 'test_helper'

class InvoicesControllerEmailTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
  end

  test "send_email delivers email for published invoice with regular customer email" do
    invoice = invoices(:published_invoice)

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      post send_email_invoice_path(invoice)
    end

    assert_redirected_to invoice
    assert_equal 'Sent E-Mail.', flash[:notice]

    # Process the enqueued job to actually send the email
    perform_enqueued_jobs

    # Check that email was delivered
    assert_equal 1, ActionMailer::Base.deliveries.size
    delivered_mail = ActionMailer::Base.deliveries.last
    assert_equal ["customer@good-company.co.uk"], delivered_mail.to
    assert_equal "My Example Invoice INV-2024-001", delivered_mail.subject
  end

  test "send_email delivers email for published invoice with auto email configuration" do
    invoice = invoices(:auto_email_invoice)

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      post send_email_invoice_path(invoice)
    end

    assert_redirected_to invoice
    assert_equal 'Sent E-Mail.', flash[:notice]

    # Process the enqueued job to actually send the email
    perform_enqueued_jobs

    # Check that email was delivered
    assert_equal 1, ActionMailer::Base.deliveries.size
    delivered_mail = ActionMailer::Base.deliveries.last
    assert_equal ["billing@autoemail.com"], delivered_mail.to
    assert_equal "Invoice AUTO-ORDER-111 - Ref: AUTO-REF-999", delivered_mail.subject
  end

  test "send_email handles customer without email gracefully" do
    invoice = invoices(:no_email_invoice)

    # Should still enqueue the job even if no email will be sent
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      post send_email_invoice_path(invoice)
    end

    assert_redirected_to invoice
    assert_equal 'Sent E-Mail.', flash[:notice]

    # Process the enqueued job
    perform_enqueued_jobs

    # No email should be delivered for customer without email
    # The mailer returns NullMail which doesn't get delivered
    assert_equal 0, ActionMailer::Base.deliveries.size
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

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      post send_email_invoice_path(invoice), headers: { 'Accept' => 'application/json' }
    end

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_equal invoice.id, json_response['id']
  end
end
