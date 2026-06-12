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

  test "publish! does nothing and returns false if already published" do
    delivery_note = delivery_notes(:published_delivery_note)
    original_document_number = delivery_note.document_number

    assert_not delivery_note.publish!

    delivery_note.reload
    assert_equal original_document_number, delivery_note.document_number
  end

  test "publish! re-dates an unpublished-and-republished note but keeps its number" do
    delivery_note = delivery_notes(:published_delivery_note)
    delivery_note.update_columns(published: false, date: Date.today - 30)
    original_document_number = delivery_note.document_number

    delivery_note.publish!

    delivery_note.reload
    assert_equal Date.today, delivery_note.date
    assert_equal original_document_number, delivery_note.document_number
  end

  test "publish! returns false without publishing when there are problems" do
    delivery_note = create_draft_delivery_note
    delivery_note.delivery_note_lines.create!(type: "text", title: "Just a note", position: 1)

    assert_not delivery_note.publish!
    assert_not delivery_note.reload.published?
  end

  # Method shape (empty for valid draft / for published doc) is verified
  # on Invoice; this confirms the DN-specific message wording.
  test "publish_problems reports the DN-specific message when missing item lines" do
    delivery_note = create_draft_delivery_note
    delivery_note.delivery_note_lines.create!(type: "text", title: "Just a note", position: 1)

    assert_includes delivery_note.publish_problems, "Delivery note has no item lines."
  end

  test "issue_acceptance_upload_token! mints, persists digest and 30-day expiry" do
    dn = delivery_notes(:published_delivery_note)
    token = dn.issue_acceptance_upload_token!
    assert token.present?
    dn.reload
    assert_equal Digest::SHA256.hexdigest(token), dn.acceptance_upload_token_digest
    assert_in_delta 30.days.from_now.to_i, dn.acceptance_upload_token_expires_at.to_i, 5
  end

  test "rotating the token invalidates the old one" do
    dn = delivery_notes(:published_delivery_note)
    old = dn.issue_acceptance_upload_token!
    dn.issue_acceptance_upload_token!
    assert_nil DeliveryNote.find_by_acceptance_upload_token(old)
  end

  test "find_by_acceptance_upload_token resolves the current token" do
    dn = delivery_notes(:published_delivery_note)
    token = dn.issue_acceptance_upload_token!
    assert_equal dn, DeliveryNote.find_by_acceptance_upload_token(token)
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

  test "delivery_timeframe localizes single day in German" do
    delivery_note = DeliveryNote.new(
      delivery_start_date: Date.new(2025, 5, 1),
      delivery_end_date: Date.new(2025, 5, 1)
    )
    I18n.with_locale(:de) do
      assert_equal "1. Mai 2025", delivery_note.delivery_timeframe
    end
  end

  test "delivery_timeframe localizes date range in same month in German" do
    delivery_note = DeliveryNote.new(
      delivery_start_date: Date.new(2025, 5, 1),
      delivery_end_date: Date.new(2025, 5, 10)
    )
    I18n.with_locale(:de) do
      assert_equal "1. bis 10. Mai 2025", delivery_note.delivery_timeframe
    end
  end

  test "delivery_timeframe localizes month range in German" do
    delivery_note = DeliveryNote.new(
      delivery_start_date: Date.new(2025, 4, 1),
      delivery_end_date: Date.new(2025, 8, 31)
    )
    I18n.with_locale(:de) do
      assert_equal "April bis August 2025", delivery_note.delivery_timeframe
    end
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

  # display_label / display_name shape is covered by InvoiceTest. This test
  # exists only to lock in the title-cased "Delivery Note" model name
  # (overridden in config/locales/en.yml so the auto-humanized "Delivery note"
  # doesn't bleed into modal titles, PDF names, and browser tab titles).
  test "display_name uses title-cased Delivery Note" do
    assert_equal "Delivery Note DN-2025-001", delivery_notes(:published_delivery_note).display_name
  end
end
