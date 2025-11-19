require "test_helper"

class InvoiceMailerTest < ActionMailer::TestCase
  def setup
    ActionMailer::Base.deliveries.clear
  end

  test "customer_email with regular customer email" do
    invoice = invoices(:published_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_not_nil mail
    # Check that it has recipients (the fixture customer has contacts)
    assert mail.to.size > 0
    assert_equal ["from@example.com"], mail.from  # from issuer fixture
    assert_equal ["bcc@example.com"], mail.bcc    # from issuer fixture
    assert_equal "My Example Invoice INV-2024-001", mail.subject

    # Check attachment
    assert_equal 1, mail.attachments.size
    attachment = mail.attachments.first
    assert_equal "test_invoice.pdf", attachment.filename
    assert_equal "application/pdf", attachment.content_type
  end

  test "customer_email with auto email configuration" do
    invoice = invoices(:auto_email_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_not_nil mail
    assert_equal ["billing@autoemail.com"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_equal ["bcc@example.com"], mail.bcc
    assert_equal "Invoice AUTO-ORDER-111 - Ref: AUTO-REF-999", mail.subject

    # Check attachment
    assert_equal 1, mail.attachments.size
    attachment = mail.attachments.first
    assert_equal "auto_invoice.pdf", attachment.filename
  end

  test "customer_email with customer without email returns NullMail" do
    invoice = invoices(:no_email_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    # ActionMailer returns NullMail when mail method returns nil
    # The mail object is a MessageDelivery that wraps the actual message
    assert_instance_of ActionMailer::Parameterized::MessageDelivery, mail
    # The underlying message should be NullMail
    assert_instance_of ActionMailer::Base::NullMail, mail.message
  end

  test "customer_email HTML template includes invoice details" do
    invoice = invoices(:published_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    html_body = mail.html_part.body.to_s

    assert_match "Dear A Good Company B.V.", html_body
    assert_match "INV-2024-001", html_body
    assert_match invoice.due_date.to_s, html_body
    assert_match "Example Company B.V.", html_body  # issuer legal_name from fixture
  end

  test "customer_email text template includes invoice details" do
    invoice = invoices(:published_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    text_body = mail.text_part.body.to_s

    assert_match "Dear A Good Company B.V.", text_body
    assert_match "INV-2024-001", text_body
    assert_match invoice.due_date.to_s, text_body
    assert_match "Example Company B.V.", text_body  # issuer legal_name from fixture
  end

  test "customer_email subject template handles empty substitution values" do
    # Create invoice with empty reference fields
    invoice = Invoice.create!(
      customer: customers(:auto_email_customer),
      project: projects(:one),  # Add required project
      attachment: attachments(:auto_email_pdf),
      document_number: "INV-EMPTY",
      published: true,
      date: Date.current,
      due_date: 30.days.from_now,
      cust_reference: "",
      cust_order: "",
      sum_net: 100.00,
      sum_total: 121.00
    )

    mail = InvoiceMailer.with(invoice: invoice).customer_email
    assert_equal "Invoice  - Ref: ", mail.subject
  end

  test "customer_email works in test environment without mailgun" do
    # Verify we're using test delivery method, not mailgun
    assert_equal :test, ActionMailer::Base.delivery_method

    invoice = invoices(:published_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    # Should not raise any mailgun-related errors
    assert_nothing_raised do
      mail.deliver_now
    end

    # Verify it was added to deliveries
    assert_equal 1, ActionMailer::Base.deliveries.size
    delivered_mail = ActionMailer::Base.deliveries.last
    assert_equal mail.to, delivered_mail.to
    assert_equal mail.subject, delivered_mail.subject
  end

  test "customer_email with customer contacts sends to all contacts for project" do
    # Create a fresh customer for this test
    customer = Customer.create!(
      matchcode: "TESTCUST",
      name: "Test Customer Ltd",
      address: "123 Test St\nTest City\nTest Country",
      vat_id: "TEST123456",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      active: true
    )

    project = Project.create!(
      matchcode: "TESTPROJ",
      description: "Test Project",
      bill_to_customer: customer
    )

    # Create contacts - one receives invoices for this project, one doesn't
    contact1 = CustomerContact.create!(
      customer: customer,
      name: "Project Contact",
      email: "project@example.com",
      receives_invoices: true
    )
    contact1.projects = [project]

    contact2 = CustomerContact.create!(
      customer: customer,
      name: "General Contact",
      email: "general@example.com",
      receives_invoices: true
    )
    # No specific projects - receives all invoices

    # Create a second project for the same customer
    other_project = Project.create!(
      matchcode: "OTHER",
      description: "Other Test Project",
      bill_to_customer: customer
    )

    contact3 = CustomerContact.create!(
      customer: customer,
      name: "Other Project Contact",
      email: "other@example.com",
      receives_invoices: true
    )
    contact3.projects = [other_project]  # Different project

    contact4 = CustomerContact.create!(
      customer: customer,
      name: "No Invoice Contact",
      email: "noinvoice@example.com",
      receives_invoices: false
    )

    # Create invoice for the project
    invoice = Invoice.create!(
      customer: customer,
      project: project,
      attachment: attachments(:invoice_pdf),
      document_number: "INV-CONTACTS-001",
      published: true,
      date: Date.current,
      due_date: 30.days.from_now,
      sum_net: 100.00,
      sum_total: 121.00
    )

    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_not_nil mail
    # Should send to contact1 (project-specific) and contact2 (general)
    assert_equal 2, mail.to.size
    assert_includes mail.to, "project@example.com"
    assert_includes mail.to, "general@example.com"
    assert_not_includes mail.to, "other@example.com"  # Different project
    assert_not_includes mail.to, "noinvoice@example.com"  # Doesn't receive invoices
  end

  test "customer_email with no matching contacts returns NullMail" do
    # Create a fresh customer with only non-receiving contacts
    customer = Customer.create!(
      matchcode: "NOEMAIL",
      name: "No Email Customer Ltd",
      address: "123 No Email St\nNo Email City\nNo Email Country",
      vat_id: "NOEMAIL123",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      active: true
    )

    project = Project.create!(
      matchcode: "NOEMAILPROJ",
      description: "No Email Project",
      bill_to_customer: customer
    )

    CustomerContact.create!(
      customer: customer,
      name: "No Invoice Contact",
      email: "noinvoice@example.com",
      receives_invoices: false
    )

    invoice = Invoice.create!(
      customer: customer,
      project: project,
      attachment: attachments(:invoice_pdf),
      document_number: "INV-NO-CONTACTS-001",
      published: true,
      date: Date.current,
      due_date: 30.days.from_now,
      sum_net: 100.00,
      sum_total: 121.00
    )

    mail = InvoiceMailer.with(invoice: invoice).customer_email

    # Should return NullMail when no contacts match
    assert_instance_of ActionMailer::Parameterized::MessageDelivery, mail
    assert_instance_of ActionMailer::Base::NullMail, mail.message
  end
end
