class AcceptanceSubmission < ApplicationRecord
  class StaleSubmission < StandardError; end
  class AlreadyAccepted < StandardError; end
  class CapReached < StandardError; end
  class NotOpen < StandardError; end

  STATUSES = %w[pending superseded accepted rejected].freeze

  belongs_to :delivery_note
  belongs_to :attachment, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :recent_first, -> { order(submitted_at: :desc) }

  # Creates a new pending submission, superseding any prior pending one and
  # dropping its blob. Serialized per note via with_lock; eligibility and cap
  # are re-checked inside the lock. Caller must already have validated the
  # file is a PDF within size limits.
  def self.submit!(delivery_note:, uploaded_file:, ip:)
    delivery_note.with_lock do
      raise NotOpen unless delivery_note.acceptance_upload_open?
      raise CapReached if delivery_note.acceptance_upload_cap_reached?

      delivery_note.acceptance_submissions.pending.each do |prev|
        att = prev.attachment
        prev.update!(status: "superseded", attachment: nil)
        att&.destroy!
      end

      attachment = Attachment.new(title: "Acceptance submission for #{delivery_note.display_name}")
      attachment.set_data(uploaded_file.read, "application/pdf")
      attachment.filename = uploaded_file.original_filename
      attachment.save!

      delivery_note.acceptance_submissions.create!(
        attachment: attachment, status: "pending",
        submitted_at: Time.current, submitted_ip: ip
      )
    end
  end

  def accept!(by:)
    delivery_note.with_lock do
      reload
      raise StaleSubmission unless status == "pending"
      raise AlreadyAccepted if delivery_note.acceptance_attachment_id.present?
      delivery_note.update!(acceptance_attachment: attachment)
      update!(status: "accepted", reviewed_by: by, reviewed_at: Time.current)
    end
  end

  def reject!(by:)
    delivery_note.with_lock do
      reload
      raise StaleSubmission unless status == "pending"
      att = attachment
      update!(status: "rejected", attachment: nil, reviewed_by: by, reviewed_at: Time.current)
      att&.destroy!
    end
  end
end
