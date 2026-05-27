require "test_helper"

class OverdueInvoicesMailerTest < ActionMailer::TestCase
  def setup
    ActionMailer::Base.deliveries.clear

    @overdue_a = invoices(:published_invoice)
    @overdue_a.update_columns(due_date: 10.days.ago.to_date, paid_at: nil)

    @overdue_b = invoices(:auto_email_invoice)
    @overdue_b.update_columns(due_date: 3.days.ago.to_date, paid_at: nil)
  end

  test "overdue_report builds an email to the issuer's reporting_email" do
    issuer_companies(:one).update!(reporting_email: "reports@example.com")
    invoices = [ @overdue_a, @overdue_b ]

    mail = OverdueInvoicesMailer.with(invoices: invoices).overdue_report

    assert_equal [ "reports@example.com" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match(/My Example/, mail.subject)
    assert_match(/2 overdue/, mail.subject)
  end

  test "overdue_report HTML body contains every required field per invoice" do
    invoices = [ @overdue_a, @overdue_b ]

    mail = OverdueInvoicesMailer.with(invoices: invoices).overdue_report
    html = mail.html_part.body.to_s

    invoices.each do |inv|
      assert_match inv.document_number, html
      assert_match inv.customer.matchcode, html
      assert_match inv.date.strftime("%d.%m.%Y"), html
      assert_match inv.due_date.strftime("%d.%m.%Y"), html
      assert_match sprintf("%.2f", inv.sum_total), html

      days_overdue = (Date.current - inv.due_date).to_i
      assert_match days_overdue.to_s, html
    end
  end

  test "overdue_report text body contains every required field per invoice" do
    invoices = [ @overdue_a ]

    mail = OverdueInvoicesMailer.with(invoices: invoices).overdue_report
    text = mail.text_part.body.to_s

    assert_match @overdue_a.document_number, text
    assert_match @overdue_a.customer.matchcode, text
    assert_match @overdue_a.date.strftime("%d.%m.%Y"), text
    assert_match @overdue_a.due_date.strftime("%d.%m.%Y"), text
    assert_match sprintf("%.2f", @overdue_a.sum_total), text
    assert_match "10 days overdue", text
  end

  test "overdue_report returns NullMail when issuer has no reporting_email" do
    issuer_companies(:one).update!(reporting_email: "")

    mail = OverdueInvoicesMailer.with(invoices: [ @overdue_a ]).overdue_report

    assert_instance_of ActionMailer::Parameterized::MessageDelivery, mail
    assert_instance_of ActionMailer::Base::NullMail, mail.message
  end
end
