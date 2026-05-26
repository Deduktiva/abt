require "test_helper"

# Exercises the PublishableDocument + DocumentWithLines filters once, via the
# Invoice routes. DeliveryNote mixes the same concerns the same way; we trust
# that wiring and avoid duplicating the assertions in delivery_notes_controller_test.rb.
class PublishableDocumentTest < ActionDispatch::IntegrationTest
  test "require_unpublished blocks edit on a published invoice" do
    invoice = invoices(:published_invoice)
    get edit_invoice_url(invoice)
    assert_redirected_to invoice_url(invoice)
    assert_match "Published invoices can not be modified", flash[:error]
  end

  test "require_unpublished blocks update on a published invoice" do
    invoice = invoices(:published_invoice)
    original_ref = invoice.cust_reference

    patch invoice_url(invoice), params: { invoice: { cust_reference: "HACKED" } }

    assert_redirected_to invoice_url(invoice)
    assert_match "Published invoices can not be modified", flash[:error]
    assert_equal original_ref, invoice.reload.cust_reference
  end

  test "require_unpublished blocks destroy on a published invoice" do
    invoice = invoices(:published_invoice)
    assert_no_difference("Invoice.count") do
      delete invoice_url(invoice)
    end
    assert_redirected_to invoice_url(invoice)
    assert_match "Published invoices can not be modified", flash[:error]
  end

  test "require_unpublished blocks preview on a published invoice" do
    invoice = invoices(:published_invoice)
    get preview_invoice_url(invoice)
    assert_redirected_to invoice_url(invoice)
    assert_match "Published invoices can not be modified", flash[:error]
  end

  test "require_published blocks send_email on a draft invoice" do
    invoice = invoices(:draft_invoice)
    post send_email_invoice_url(invoice)
    assert_redirected_to invoice_url(invoice)
    assert_match "Draft invoices can not be used for this action", flash[:error]
  end

  test "require_published blocks mark_paid on a draft invoice" do
    invoice = invoices(:draft_invoice)
    post mark_paid_invoice_url(invoice)
    assert_redirected_to invoice_url(invoice)
    assert_match "Draft invoices can not be used for this action", flash[:error]
  end

  test "require_item_line blocks preview on an invoice with no item lines" do
    invoice = create_draft_invoice(cust_reference: "NO_ITEMS")
    get preview_invoice_url(invoice)
    assert_redirected_to invoice_url(invoice)
    assert_match(/no item lines/i, flash[:error])
  end

  test "publish_problems blocks publish on an invoice with no item lines" do
    invoice = create_draft_invoice(cust_reference: "NO_ITEMS_PUBLISH")
    post publish_invoice_url(invoice)
    assert_redirected_to invoice_url(invoice)
    assert_match(/no item lines/i, flash[:error])
    assert_not invoice.reload.published?
  end

  test "require_item_line allows preview when an item line exists" do
    invoice = create_invoice_with_item_line(cust_reference: "WITH_ITEM")
    get preview_invoice_url(invoice)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end
end
