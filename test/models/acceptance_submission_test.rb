require "test_helper"

class AcceptanceSubmissionTest < ActiveSupport::TestCase
  def published_note
    dn = delivery_notes(:published_delivery_note)
    dn.issue_acceptance_upload_token!
    dn
  end

  def pdf_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/acceptance.pdf"), "application/pdf")
  end

  test "submit! creates a pending submission with an attachment" do
    dn = published_note
    sub = AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "203.0.113.5")
    assert_equal "pending", sub.status
    assert sub.attachment.present?
    assert_equal "203.0.113.5", sub.submitted_ip
  end

  test "a second submit supersedes the first and drops its blob" do
    dn = published_note
    first = AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "1.1.1.1")
    first_attachment_id = first.attachment_id
    AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "1.1.1.1")
    first.reload
    assert_equal "superseded", first.status
    assert_nil first.attachment_id
    assert_not Attachment.exists?(first_attachment_id)
    assert_equal 1, dn.acceptance_submissions.pending.count
  end

  test "accept! promotes the reviewed attachment to the official slot" do
    dn = published_note
    sub = AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "1.1.1.1")
    sub.accept!(by: users(:alice))
    dn.reload
    assert_equal sub.attachment_id, dn.acceptance_attachment_id
    assert_equal "accepted", sub.reload.status
    assert_not dn.acceptance_upload_open?
  end

  test "accept! refuses a superseded submission" do
    dn = published_note
    stale = AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "1.1.1.1")
    AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "1.1.1.1")
    assert_raises(AcceptanceSubmission::StaleSubmission) { stale.accept!(by: users(:alice)) }
  end

  test "reject! drops the blob, keeps the row, and reopens the link" do
    dn = published_note
    sub = AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "1.1.1.1")
    att_id = sub.attachment_id
    sub.reject!(by: users(:alice))
    assert_equal "rejected", sub.reload.status
    assert_nil sub.attachment_id
    assert_not Attachment.exists?(att_id)
    assert dn.reload.acceptance_upload_open?, "link stays open after rejection"
  end

  test "submit! refuses when the note is no longer open" do
    dn = published_note
    AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "1.1.1.1").accept!(by: users(:alice))
    assert_raises(AcceptanceSubmission::NotOpen) do
      AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "1.1.1.1")
    end
  end

  test "submit! refuses once the per-token cap is reached" do
    dn = published_note
    DeliveryNote::ACCEPTANCE_SUBMISSIONS_PER_TOKEN.times do
      AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "1.1.1.1")
    end
    assert_raises(AcceptanceSubmission::CapReached) do
      AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "1.1.1.1")
    end
  end

  test "rotating the token resets the per-token submission window" do
    dn = published_note
    DeliveryNote::ACCEPTANCE_SUBMISSIONS_PER_TOKEN.times do
      AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf_upload, ip: "1.1.1.1")
    end
    assert dn.acceptance_upload_cap_reached?
    dn.issue_acceptance_upload_token!(now: 1.hour.from_now)
    assert_not dn.acceptance_upload_cap_reached?
  end
end
