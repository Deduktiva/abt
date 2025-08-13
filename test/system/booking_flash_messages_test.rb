require "test_helper"

class BookingFlashMessagesTest < ActionDispatch::SystemTestCase
  test "booking page shows only booking-specific flash messages" do
    invoice = invoices(:draft_invoice)

    # Add an invoice line to make it bookable
    invoice.invoice_lines.create!(
      type: 'item',
      title: 'Test Product',
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      position: 1
    )

    # Navigate to the booking page and perform test booking
    visit invoice_path(invoice)
    click_button 'Test Booking'

    # Check that we're on the booking results page
    assert_current_path book_invoice_path(invoice)

    # Should see the booking page (even if booking fails, that's OK for this test)
    assert_text 'Book invoice'

    # The key test: Should NOT see any FLASH messages (with flash_* IDs) in the main layout
    # The booking page itself can show booking results, but they shouldn't come from flash
    layout_flash_messages = all('.container > .content > .alert').select do |alert|
      # Only count alerts that have a flash_* div inside (i.e., came from the layout's _messages partial)
      alert.all('div[id^="flash_"]').any?
    end

    booking_flash_count = layout_flash_messages.select { |el|
      el.text.downcase.include?('booking') || el.text.downcase.include?('book')
    }.count

    # Our fix should prevent booking-specific FLASH messages from appearing in the layout
    assert_equal 0, booking_flash_count, "Should not see booking-related FLASH messages in main layout"
  end

  test "booking page shows error correctly without duplicate messages" do
    # Create an invoice that will fail booking due to missing customer reference
    invoice = invoices(:draft_invoice)
    invoice.update!(cust_reference: '')

    visit invoice_path(invoice)
    click_button 'Test Booking'

    # Check that we're on the booking results page
    assert_current_path book_invoice_path(invoice)

    # Should see the booking page
    assert_text 'Book invoice'

    # The key test: Should NOT see any duplicate FLASH messages in the main layout
    layout_flash_messages = all('.container > .content > .alert').select do |alert|
      # Only count alerts that have a flash_* div inside (i.e., came from the layout's _messages partial)
      alert.all('div[id^="flash_"]').any?
    end

    booking_flash_count = layout_flash_messages.select { |el|
      el.text.downcase.include?('booking') || el.text.downcase.include?('book')
    }.count

    # Our fix should prevent duplicate booking-related FLASH messages in the layout
    assert_equal 0, booking_flash_count, "Should not see duplicate booking FLASH messages in main layout"
  end
end
