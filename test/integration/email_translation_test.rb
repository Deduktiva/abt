require 'test_helper'

class EmailTranslationTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "invoice email uses English translations for English customers" do
    english_customer = customers(:good_eu) # Customer with English language
    invoice = invoices(:published_invoice)
    invoice.update!(customer: english_customer)

    mail = InvoiceMailer.with(invoice: invoice).customer_email

    # Test subject line uses English
    assert_includes mail.subject, "Invoice"
    refute_includes mail.subject, "Rechnung"

    # Test email body uses English
    assert_includes mail.html_part.body.to_s, "Dear"
    assert_includes mail.html_part.body.to_s, "We&#39;ve attached your invoice"
    assert_includes mail.html_part.body.to_s, "Thank you for your business"

    # Should not contain German text
    refute_includes mail.html_part.body.to_s, "Sehr geehrte"
    refute_includes mail.html_part.body.to_s, "Vielen Dank für"
  end

  test "invoice email uses German translations for German customers" do
    german_customer = customers(:good_eu)
    german_customer.update!(language: languages(:german))
    invoice = invoices(:published_invoice)
    invoice.update!(customer: german_customer)

    mail = InvoiceMailer.with(invoice: invoice).customer_email

    # Test subject line uses German
    assert_includes mail.subject, "Rechnung"
    refute_includes mail.subject, " Invoice "

    # Test email body uses German
    assert_includes mail.html_part.body.to_s, "Sehr geehrte Damen und Herren"
    assert_includes mail.html_part.body.to_s, "Anbei finden Sie die Rechnung"
    assert_includes mail.html_part.body.to_s, "Vielen Dank für Ihr Vertrauen"

    # Should not contain English text
    refute_includes mail.html_part.body.to_s, "Dear"
    refute_includes mail.html_part.body.to_s, "We&#39;ve attached your invoice"
    refute_includes mail.html_part.body.to_s, "Thank you for your business"
  end

  test "delivery note email uses German translations for German customers" do
    german_customer = customers(:good_eu)
    german_customer.update!(language: languages(:german))
    delivery_note = delivery_notes(:published_delivery_note)
    delivery_note.update!(customer: german_customer)

    mail = DeliveryNoteMailer.with(delivery_note: delivery_note).customer_email

    # Test subject line uses German
    assert_includes mail.subject, "Lieferschein"
    refute_includes mail.subject, "Delivery Note"

    # Test email body uses German
    assert_includes mail.html_part.body.to_s, "Sehr geehrte Damen und Herren"
    assert_includes mail.html_part.body.to_s, "Anbei finden Sie den Lieferschein"
    assert_includes mail.html_part.body.to_s, "Vielen Dank für Ihr Vertrauen"
  end

  test "delivery note email uses English translations for English customers" do
    english_customer = customers(:good_eu)
    english_customer.update!(language: languages(:english))
    delivery_note = delivery_notes(:published_delivery_note)
    delivery_note.update!(customer: english_customer)

    mail = DeliveryNoteMailer.with(delivery_note: delivery_note).customer_email

    # Test subject line uses English
    assert_includes mail.subject, "Delivery Note"
    refute_includes mail.subject, "Lieferschein"

    # Test email body uses English
    assert_includes mail.html_part.body.to_s, "Dear"
    assert_includes mail.html_part.body.to_s, "We&#39;ve attached your delivery note"
    assert_includes mail.html_part.body.to_s, "Thank you for your business"
  end
end
