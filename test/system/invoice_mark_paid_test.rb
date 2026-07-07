require "application_system_test_case"

class InvoiceMarkPaidTest < ApplicationSystemTestCase
  setup do
    @invoice = invoices(:published_invoice)
  end

  test "mark paid via inline modal on unpaid invoice" do
    @invoice.update!(paid_at: nil)

    visit invoice_path(@invoice)

    # The trigger lives in the Payment Status row, not the bottom action row.
    # Modal starts hidden via d-none.
    assert_selector ".mark-paid-modal", visible: :hidden
    click_on "Paid…"

    # Modal opens (d-none removed).
    assert_selector ".mark-paid-modal", visible: :visible

    within ".mark-paid-modal" do
      fill_in "paid_at", with: Date.current.strftime("%Y-%m-%d")
      click_on "Mark Paid"
    end

    # Redirect back to show page with the invoice now marked paid.
    assert_text(/Paid/)
    # No "Unpaid" badge (the bare word "Unpaid" still appears inside the
    # "Unpaid" button that's now rendered).
    assert_no_selector ".badge.bg-warning", text: "Unpaid"
    assert_equal Date.current, @invoice.reload.paid_at.to_date
  end

  test "mark unpaid via inline button on paid invoice" do
    @invoice.update!(paid_at: Date.current)

    visit invoice_path(@invoice)

    accept_confirm do
      click_on "Unpaid"
    end

    assert_text "Unpaid", wait: 5
    assert_nil @invoice.reload.paid_at
  end

  test "cancel button closes the mark paid modal" do
    @invoice.update!(paid_at: nil)

    visit invoice_path(@invoice)

    click_on "Paid…"
    assert_selector ".mark-paid-modal", visible: :visible

    within ".mark-paid-modal" do
      click_on "Cancel"
    end

    assert_selector ".mark-paid-modal", visible: :hidden
    assert_text "Unpaid"
    assert_nil @invoice.reload.paid_at
  end
end
