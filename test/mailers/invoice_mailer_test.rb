require "test_helper"

class InvoiceMailerTest < ActionMailer::TestCase
  def setup
    ActionMailer::Base.deliveries.clear
  end

  test "customer_email puts all matching contacts in To:" do
    invoice = invoices(:published_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_not_nil mail
    # good_eu has two contacts that match project `one`:
    #   - good_eu_accounting (no projects → all)
    #   - good_eu_project_one_lead (scoped to project `one`)
    assert_equal [ "customer@good-company.co.uk", "proj001-lead@good-company.co.uk" ].sort, mail.to.sort
    assert mail.cc.blank?, "expected mail.cc to be blank, got #{mail.cc.inspect}"
    assert_equal [ "from@example.com" ], mail.from
    assert_equal [ "bcc@example.com" ], mail.bcc
    assert_equal "My Example Invoice INV-2024-001", mail.subject

    assert_equal 1, mail.attachments.size
    assert_equal "test_invoice.pdf", mail.attachments.first.filename
  end

  test "customer_email skips contacts whose project does not match the invoice's project" do
    # good_eu_project_one_lead is scoped to project `one`. An invoice on
    # project `two` should NOT include that contact.
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:two),
      attachment: attachments(:invoice_pdf),
      date: Date.current,
      due_date: 30.days.from_now
    )
    invoice.invoice_lines.create!(type: "item", title: "X", quantity: 1.0, rate: 100.0, position: 1)
    invoice.update!(published: true, document_number: "INV-PROJ-FILTER", sum_net: 100.00, sum_total: 121.00)

    mail = InvoiceMailer.with(invoice: invoice).customer_email
    assert_equal [ "customer@good-company.co.uk" ], mail.to
  end

  test "customer_email with auto + cc_contacts mode keeps auto in To: and contacts in Cc:" do
    invoice = invoices(:auto_email_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_equal [ "billing@autoemail.com" ], mail.to
    assert_equal [ "backup@autoemail.com" ], mail.cc
    assert_equal "Invoice AUTO-ORDER-111 - Ref: AUTO-REF-999", mail.subject
  end

  test "customer_email with auto + replace_contacts mode ignores contacts" do
    customers(:auto_email_customer).update!(invoice_email_auto_contact_mode: "replace_contacts")
    invoice = invoices(:auto_email_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_equal [ "billing@autoemail.com" ], mail.to
    assert mail.cc.blank?, "expected mail.cc to be blank, got #{mail.cc.inspect}"
  end

  test "customer_email with auto + cc_contacts deduplicates a contact whose email matches the auto address case-insensitively" do
    customer = customers(:auto_email_customer)
    customer.customer_contacts.create!(name: "Shouty", email: customer.invoice_email_auto_to.upcase, receives_invoice_emails: true)
    invoice = invoices(:auto_email_invoice)

    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_equal [ "billing@autoemail.com" ], mail.to
    # backup@autoemail.com (from the auto_email_contact fixture) survives;
    # the BILLING@AUTOEMAIL.COM contact was dropped from CC.
    assert_equal [ "backup@autoemail.com" ], mail.cc
  end

  test "customer_email with auto + cc_contacts but no matching contact omits cc" do
    customers(:auto_email_customer).customer_contacts.destroy_all
    invoice = invoices(:auto_email_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_equal [ "billing@autoemail.com" ], mail.to
    assert mail.cc.blank?, "expected mail.cc to be blank, got #{mail.cc.inspect}"
  end

  test "customer_email with customer without contacts and no auto returns NullMail" do
    invoice = invoices(:no_email_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_instance_of ActionMailer::Parameterized::MessageDelivery, mail
    assert_instance_of ActionMailer::Base::NullMail, mail.message
  end

  test "customer_email HTML template includes invoice details" do
    invoice = invoices(:published_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    html_body = mail.html_part.body.to_s

    assert_match "Dear A Good Company B.V.", html_body
    assert_match "INV-2024-001", html_body
    assert_match invoice.due_date.to_s, html_body
    assert_match "Example Company B.V.", html_body
  end

  test "customer_email text template includes invoice details" do
    invoice = invoices(:published_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    text_body = mail.text_part.body.to_s

    assert_match "Dear A Good Company B.V.", text_body
    assert_match "INV-2024-001", text_body
    assert_match invoice.due_date.to_s, text_body
    assert_match "Example Company B.V.", text_body
  end

  test "customer_email subject strips CRLF from user-controlled substitution values" do
    invoice = invoices(:auto_email_invoice)
    invoice.update!(
      cust_order: "ORDER\r\nBcc: attacker@example.com",
      cust_reference: "REF\nX-Injected: yes"
    )

    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_equal "Invoice ORDER Bcc: attacker@example.com - Ref: REF X-Injected: yes", mail.subject
    assert_no_match(/[\r\n]/, mail.subject)
  end

  test "customer_email strips CRLF from issuer-controlled short_name in subject and From" do
    IssuerCompany.get_the_issuer!.update!(short_name: "Evil\r\nX-Injected: yes")
    invoice = invoices(:published_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_no_match(/[\r\n]/, mail.subject)
    assert_no_match(/[\r\n]/, mail.from.join)
    assert_no_match(/[\r\n]/, mail["from"].decoded)
  end

  test "customer_email subject template handles empty substitution values" do
    invoice = Invoice.create!(
      customer: customers(:auto_email_customer),
      project: projects(:one),
      attachment: attachments(:auto_email_pdf),
      date: Date.current,
      due_date: 30.days.from_now,
      cust_reference: "",
      cust_order: ""
    )
    invoice.invoice_lines.create!(type: "item", title: "X", quantity: 1.0, rate: 100.0, position: 1)
    invoice.update!(published: true, document_number: "INV-EMPTY", sum_net: 100.00, sum_total: 121.00)

    mail = InvoiceMailer.with(invoice: invoice).customer_email
    assert_equal "Invoice  - Ref: ", mail.subject
  end

  test "customer_email subject template handles nil substitution values" do
    invoice = Invoice.create!(
      customer: customers(:auto_email_customer),
      project: projects(:one),
      attachment: attachments(:auto_email_pdf),
      date: Date.current,
      due_date: 30.days.from_now,
      cust_reference: nil,
      cust_order: nil
    )
    invoice.invoice_lines.create!(type: "item", title: "X", quantity: 1.0, rate: 100.0, position: 1)
    invoice.update!(published: true, document_number: "INV-NIL", sum_net: 100.00, sum_total: 121.00)

    mail = InvoiceMailer.with(invoice: invoice).customer_email
    assert_equal "Invoice  - Ref: ", mail.subject
  end

  test "customer_email uses salutation_line when exactly one contact resolves as recipient" do
    customer_contacts(:good_eu_accounting).update!(salutation_line: "Hi tester,")

    # Project `two` matches only good_eu_accounting (good_eu_project_one_lead
    # is scoped to project `one`), so the To: line resolves to a single
    # contact and its salutation_line wins.
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:two),
      attachment: attachments(:invoice_pdf),
      date: Date.current,
      due_date: 30.days.from_now
    )
    invoice.invoice_lines.create!(type: "item", title: "X", quantity: 1.0, rate: 100.0, position: 1)
    invoice.update!(published: true, document_number: "INV-SALUT-1", sum_net: 100.00, sum_total: 121.00)

    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_equal [ "customer@good-company.co.uk" ], mail.to
    assert_match "Hi tester,", mail.text_part.body.to_s
    assert_match "Hi tester,", mail.html_part.body.to_s
    assert_no_match(/Dear A Good Company B\.V\./, mail.text_part.body.to_s)
    assert_no_match(/Dear A Good Company B\.V\./, mail.html_part.body.to_s)
  end

  test "customer_email falls back to greeting when the single resolved contact has no salutation_line" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:two),
      attachment: attachments(:invoice_pdf),
      date: Date.current,
      due_date: 30.days.from_now
    )
    invoice.invoice_lines.create!(type: "item", title: "X", quantity: 1.0, rate: 100.0, position: 1)
    invoice.update!(published: true, document_number: "INV-SALUT-NIL", sum_net: 100.00, sum_total: 121.00)

    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_equal [ "customer@good-company.co.uk" ], mail.to
    assert_match "Dear A Good Company B.V.,", mail.text_part.body.to_s
    assert_match "Dear A Good Company B.V.,", mail.html_part.body.to_s
  end

  test "customer_email falls back to greeting when multiple contacts match, even if both have salutation_line set" do
    customer_contacts(:good_eu_accounting).update!(salutation_line: "Hi tester one,")
    customer_contacts(:good_eu_project_one_lead).update!(salutation_line: "Hi tester two,")

    # published_invoice is on project `one` → both contacts match.
    invoice = invoices(:published_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_equal 2, mail.to.size
    text_body = mail.text_part.body.to_s
    assert_match "Dear A Good Company B.V.,", text_body
    assert_no_match(/Hi tester one,/, text_body)
    assert_no_match(/Hi tester two,/, text_body)
  end

  test "customer_email in auto-email replace_contacts mode falls back to greeting even with a single contact's salutation_line" do
    customer = customers(:auto_email_customer)
    customer.update!(invoice_email_auto_contact_mode: "replace_contacts")
    customer_contacts(:auto_email_contact).update!(salutation_line: "Hi auto tester,")

    invoice = invoices(:auto_email_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_equal [ "billing@autoemail.com" ], mail.to
    text_body = mail.text_part.body.to_s
    assert_no_match(/Hi auto tester,/, text_body)
    assert_match(/Auto Email Corp/, text_body)
  end

  test "customer_email works in test environment without mailgun" do
    assert_equal :test, ActionMailer::Base.delivery_method

    invoice = invoices(:published_invoice)
    mail = InvoiceMailer.with(invoice: invoice).customer_email

    assert_nothing_raised do
      mail.deliver_now
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    delivered_mail = ActionMailer::Base.deliveries.last
    assert_equal mail.to, delivered_mail.to
    assert_equal mail.subject, delivered_mail.subject
  end
end
