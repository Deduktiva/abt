require 'test_helper'

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
    assert_equal 'Draft invoices can not be used for this action.', flash[:error]
    invoice.reload
    assert_nil invoice.paid_at
  end

  test "mark_paid handles invalid date" do
    invoice = invoices(:published_invoice)

    post mark_paid_invoice_path(invoice), params: { paid_at: 'not-a-date' }

    assert_redirected_to invoice
    assert_equal 'Invalid date.', flash[:alert]
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
    assert_equal 'Draft invoices can not be used for this action.', flash[:error]
  end

  test "show page exposes unpaid status with mark paid form for booked invoice" do
    invoice = invoices(:published_invoice)
    invoice.update!(paid_at: nil)

    get invoice_path(invoice)

    assert_response :success
    assert_select '.badge.bg-warning', text: 'Unpaid'
    assert_select "form[action=\"#{mark_paid_invoice_path(invoice)}\"]"
    assert_select "input[type='date'][name='paid_at']"
    assert_select 'input[type="submit"][value="Mark Paid"]'
  end

  test "show page exposes paid status with mark unpaid button when paid" do
    invoice = invoices(:published_invoice)
    invoice.update!(paid_at: Date.current)

    get invoice_path(invoice)

    assert_response :success
    assert_select '.badge.bg-success', text: /Paid/
    assert_select "form[action=\"#{mark_unpaid_invoice_path(invoice)}\"]"
  end

  test "show page does not show payment status for draft invoices" do
    invoice = invoices(:draft_invoice)

    get invoice_path(invoice)

    assert_response :success
    assert_select 'strong', text: 'Payment Status:', count: 0
  end
end
