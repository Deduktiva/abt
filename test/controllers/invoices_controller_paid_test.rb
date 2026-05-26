require "test_helper"

class InvoicesControllerPaidTest < ActionDispatch::IntegrationTest
  test "published invoice defaults to unpaid" do
    invoice = invoices(:published_invoice)
    assert_nil invoice.paid_at
    assert_not invoice.paid?
  end

  test "mark_paid sets paid_at to today by default" do
    invoice = invoices(:published_invoice)

    post mark_paid_invoice_path(invoice)

    assert_redirected_to invoice
    invoice.reload
    assert_equal Date.current, invoice.paid_at
    assert invoice.paid?
  end

  test "mark_paid accepts a specific date" do
    invoice = invoices(:published_invoice)
    paid_on = Date.current - 5.days

    post mark_paid_invoice_path(invoice), params: { paid_at: paid_on.to_s }

    assert_redirected_to invoice
    invoice.reload
    assert_equal paid_on, invoice.paid_at
  end

  test "mark_paid rejects draft invoices" do
    invoice = invoices(:draft_invoice)

    post mark_paid_invoice_path(invoice)

    assert_redirected_to invoice
    assert_equal "Draft invoices can not be used for this action.", flash[:error]
    invoice.reload
    assert_nil invoice.paid_at
  end

  test "mark_paid handles invalid date" do
    invoice = invoices(:published_invoice)

    post mark_paid_invoice_path(invoice), params: { paid_at: "not-a-date" }

    assert_redirected_to invoice
    assert_equal "Invalid date.", flash[:alert]
    invoice.reload
    assert_nil invoice.paid_at
  end

  test "mark_unpaid clears paid_at" do
    invoice = invoices(:published_invoice)
    invoice.update!(paid_at: Date.current)

    post mark_unpaid_invoice_path(invoice)

    assert_redirected_to invoice
    invoice.reload
    assert_nil invoice.paid_at
    assert_not invoice.paid?
  end

  test "mark_unpaid rejects draft invoices" do
    invoice = invoices(:draft_invoice)

    post mark_unpaid_invoice_path(invoice)

    assert_redirected_to invoice
    assert_equal "Draft invoices can not be used for this action.", flash[:error]
  end

  test "show page exposes unpaid status with mark paid form for published invoice" do
    invoice = invoices(:published_invoice)
    invoice.update!(paid_at: nil)

    get invoice_path(invoice)

    assert_response :success
    assert_select ".badge.bg-warning", text: "Unpaid"
    assert_select "button", text: /Mark Paid/
    assert_select ".mark-paid-modal form[action=?]", mark_paid_invoice_path(invoice)
    assert_select ".mark-paid-modal input[type='date'][name='paid_at']"
    assert_select ".mark-paid-modal input[type='submit'][value='Mark Paid']"
  end

  test "show page exposes paid status with mark unpaid button when paid" do
    invoice = invoices(:published_invoice)
    invoice.update!(paid_at: Date.current)

    get invoice_path(invoice)

    assert_response :success
    assert_select ".badge.bg-success", text: /Paid/
    assert_select "form[action=?]", mark_unpaid_invoice_path(invoice)
    assert_select "form[action=?] button[type='submit']", mark_unpaid_invoice_path(invoice), text: "Mark Unpaid"
  end

  test "show page does not show payment status for draft invoices" do
    invoice = invoices(:draft_invoice)

    get invoice_path(invoice)

    assert_response :success
    assert_select "strong", text: "Payment Status:", count: 0
  end

  test "index unpaid filter shows only unpaid published invoices" do
    unpaid = invoices(:published_invoice)
    unpaid.update!(paid_at: nil)
    paid = invoices(:auto_email_invoice)
    paid.update!(paid_at: Date.current)
    draft = invoices(:draft_invoice)

    get invoices_path(filter: "unpaid", year: Date.current.year)

    assert_response :success
    assert_select ".invoice-filter .active", text: "Unpaid"
    assert_select "a", text: unpaid.document_number
    assert_select "a", text: paid.document_number, count: 0
    assert_select "a", text: "Draft ##{draft.id}", count: 0
  end

  test "index has Unpaid filter button" do
    get invoices_path

    assert_response :success
    assert_select ".invoice-filter a", text: "Unpaid"
  end

  test "index shows Overdue label for unpaid invoices past due date" do
    invoice = invoices(:published_invoice)
    invoice.update!(paid_at: nil, due_date: Date.current - 1.day)

    get invoices_path(year: Date.current.year)

    assert_response :success
    assert_select ".badge.bg-danger", text: "Overdue"
  end

  test "index shows Unpaid label for unpaid invoices not yet past due date" do
    invoice = invoices(:published_invoice)
    invoice.update!(paid_at: nil, due_date: Date.current + 1.day)

    get invoices_path(year: Date.current.year)

    assert_response :success
    assert_select ".badge.bg-warning", text: "Unpaid"
    assert_select ".badge.bg-danger", text: "Overdue", count: 0
  end

  test "show page shows Overdue label for unpaid invoices past due date" do
    invoice = invoices(:published_invoice)
    invoice.update!(paid_at: nil, due_date: Date.current - 1.day)

    get invoice_path(invoice)

    assert_response :success
    assert_select ".badge.bg-danger", text: "Overdue"
    assert_select ".badge.bg-warning", text: "Unpaid", count: 0
  end

  test "unpaid filter includes overdue invoices" do
    invoice = invoices(:published_invoice)
    invoice.update!(paid_at: nil, due_date: Date.current - 5.days)

    get invoices_path(filter: "unpaid", year: Date.current.year)

    assert_response :success
    assert_select "a", text: invoice.document_number
    assert_select ".badge.bg-danger", text: "Overdue"
  end
end
