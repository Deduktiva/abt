require "test_helper"

class DeliveryNoteTest < ActiveSupport::TestCase
  test "should require customer_id" do
    delivery_note = DeliveryNote.new
    assert_not delivery_note.valid?
    assert_includes delivery_note.errors[:customer_id], "can't be blank"
  end

  test "should require delivery_start_date" do
    delivery_note = DeliveryNote.new(customer: customers(:good_eu), project: projects(:one))
    assert_not delivery_note.valid?
    assert_includes delivery_note.errors[:delivery_start_date], "can't be blank"
  end

  test "email_sent scope returns delivery notes with email_sent_at" do
    delivery_note = delivery_notes(:published_delivery_note)
    delivery_note.update_column(:email_sent_at, Time.current)

    sent_notes = DeliveryNote.email_sent
    assert_includes sent_notes, delivery_note
  end

  test "email_unsent scope returns delivery notes without email_sent_at that have customer email" do
    delivery_note = delivery_notes(:published_delivery_note)
    delivery_note.update_column(:email_sent_at, nil)

    unsent_notes = DeliveryNote.email_unsent
    assert_includes unsent_notes, delivery_note
  end

  test "published scope returns only published delivery notes" do
    published_notes = DeliveryNote.published
    assert_includes published_notes, delivery_notes(:published_delivery_note)
    assert_not_includes published_notes, delivery_notes(:draft_delivery_note)
  end

  test "publish! sets published to true and assigns document number" do
    delivery_note = delivery_notes(:draft_delivery_note)
    delivery_note.publish!

    delivery_note.reload
    assert delivery_note.published?
    assert_not_nil delivery_note.document_number
    assert_equal Date.today, delivery_note.date
  end

  test "publish! does nothing if already published" do
    delivery_note = delivery_notes(:published_delivery_note)
    original_document_number = delivery_note.document_number

    delivery_note.publish!

    delivery_note.reload
    assert_equal original_document_number, delivery_note.document_number
  end

  test "delivery_timeframe formats single day correctly" do
    delivery_note = DeliveryNote.new(
      delivery_start_date: Date.new(2025, 5, 1),
      delivery_end_date: Date.new(2025, 5, 1)
    )
    assert_equal "May 1, 2025", delivery_note.delivery_timeframe
  end

  test "delivery_timeframe formats date range in same month correctly" do
    delivery_note = DeliveryNote.new(
      delivery_start_date: Date.new(2025, 5, 1),
      delivery_end_date: Date.new(2025, 5, 10)
    )
    assert_equal "1. to 10. May 2025", delivery_note.delivery_timeframe
  end

  test "delivery_timeframe formats full month correctly" do
    delivery_note = DeliveryNote.new(
      delivery_start_date: Date.new(2025, 4, 1),
      delivery_end_date: Date.new(2025, 4, 30)
    )
    assert_equal "April 2025", delivery_note.delivery_timeframe
  end

  test "delivery_timeframe formats month range correctly" do
    delivery_note = DeliveryNote.new(
      delivery_start_date: Date.new(2025, 4, 1),
      delivery_end_date: Date.new(2025, 8, 31)
    )
    assert_equal "April to August 2025", delivery_note.delivery_timeframe
  end

  test "delivery_timeframe returns nil when no start date" do
    delivery_note = DeliveryNote.new
    assert_nil delivery_note.delivery_timeframe
  end

  test "should validate delivery end date is not before start date" do
    delivery_note = DeliveryNote.new(
      customer: customers(:good_eu),
      project: projects(:one),
      delivery_start_date: Date.new(2025, 5, 10),
      delivery_end_date: Date.new(2025, 5, 5)
    )
    assert_not delivery_note.valid?
    assert_includes delivery_note.errors[:delivery_end_date], "cannot be before the start date"
  end

  test "should allow delivery end date same as start date" do
    delivery_note = DeliveryNote.new(
      customer: customers(:good_eu),
      project: projects(:one),
      delivery_start_date: Date.new(2025, 5, 10),
      delivery_end_date: Date.new(2025, 5, 10)
    )
    assert delivery_note.valid?
  end

  test "should allow delivery end date after start date" do
    delivery_note = DeliveryNote.new(
      customer: customers(:good_eu),
      project: projects(:one),
      delivery_start_date: Date.new(2025, 5, 10),
      delivery_end_date: Date.new(2025, 5, 15)
    )
    assert delivery_note.valid?
  end
end
