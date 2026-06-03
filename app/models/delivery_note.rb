class DeliveryNote < ApplicationRecord
  include YearFilterable
  include HasLineItems
  include ScopedThroughCustomer
  include DigestedToken
  include DocumentIdentity

  ACCEPTANCE_TOKEN_TTL = (Settings.customer_portal.link_expiry_days || 30).days
  ACCEPTANCE_SUBMISSIONS_PER_TOKEN = Settings.customer_portal.submissions_per_token || 20
  has_line_items :delivery_note_lines

  validates :customer_id, presence: true
  validates :delivery_start_date, presence: true
  validate :delivery_end_date_after_start_date
  scope :with_pending_acceptance, -> { where(id: AcceptanceSubmission.pending.select(:delivery_note_id)) }
  scope :email_unsent, -> {
    where(email_sent_at: nil).where(<<~SQL.squish)
      EXISTS (
        SELECT 1 FROM customer_contacts cc
        LEFT JOIN customer_contact_projects ccp ON ccp.customer_contact_id = cc.id
        WHERE cc.customer_id = delivery_notes.customer_id
          AND cc.receives_delivery_note_emails = TRUE
          AND (ccp.project_id IS NULL OR ccp.project_id = delivery_notes.project_id)
      )
    SQL
  }

  def email_recipients
    customer.contacts_for_delivery_note(self).map(&:to_email_address)
  end

  # The contact whose salutation_line should personalize this delivery note's
  # email, or nil to fall back to the I18n greeting. Returns the contact only
  # when the To: line resolves to exactly one CustomerContact.
  def email_salutation_contact
    contacts = customer.contacts_for_delivery_note(self)
    contacts.size == 1 ? contacts.first : nil
  end

  def emailable?
    email_recipients.any?
  end

  belongs_to :customer
  belongs_to :project
  belongs_to :acceptance_attachment, class_name: "Attachment", optional: true
  belongs_to :invoice, optional: true

  has_many :delivery_note_lines, -> { order(:position, :id) }, dependent: :delete_all
  accepts_nested_attributes_for :delivery_note_lines, allow_destroy: true, reject_if: :all_blank

  has_many :acceptance_submissions, dependent: :destroy

  def issue_acceptance_upload_token!(now: Time.current)
    plaintext, digest = self.class.generate_token
    update!(acceptance_upload_token_digest: digest,
            acceptance_upload_token_minted_at: now,
            acceptance_upload_token_expires_at: now + ACCEPTANCE_TOKEN_TTL)
    plaintext
  end

  def self.find_by_acceptance_upload_token(plaintext)
    return nil if plaintext.blank?
    find_by(acceptance_upload_token_digest: digest_token(plaintext))
  end

  def acceptance_upload_open?(now: Time.current)
    published? && acceptance_attachment_id.nil? &&
      acceptance_upload_token_expires_at.present? &&
      acceptance_upload_token_expires_at > now
  end

  def acceptance_upload_cap_reached?
    return false if acceptance_upload_token_minted_at.blank?
    acceptance_submissions
      .where("submitted_at >= ?", acceptance_upload_token_minted_at)
      .count >= ACCEPTANCE_SUBMISSIONS_PER_TOKEN
  end

  # Mirrors InvoicePublisher#publish!: returns false without mutating when the
  # document can't be published (already published, or publish_problems present)
  # and true after a successful publish.
  def publish!
    return false if published?
    return false if publish_problems.any?

    self.date = Date.today
    self.document_number ||= DocumentNumber.get_next_for("delivery_note", date)
    self.published = true
    save!
    true
  end

  # Mirrors Invoice#publish_problems: returns user-facing strings describing
  # why publishing would fail, or [] when the document is ready. Unlike
  # invoices, delivery notes have no customer-snapshot, tax, or VAT-ID
  # validation, so the surface is small — but exposing the method keeps the
  # controller flow symmetric and gives future constraints a home.
  def publish_problems
    problems = []
    return problems if published?

    problems << "Delivery note has no item lines." unless has_items?

    problems
  end

  def delivery_timeframe
    return nil unless delivery_start_date

    if delivery_end_date.nil? || delivery_start_date == delivery_end_date
      # Single day
      format_date_for_timeframe(delivery_start_date)
    elsif same_month?(delivery_start_date, delivery_end_date)
      # Same month - show date range or just month if full month
      if full_month?(delivery_start_date, delivery_end_date)
        delivery_start_date.strftime("%B %Y")
      else
        "#{delivery_start_date.day}. to #{delivery_end_date.day}. #{delivery_start_date.strftime("%B %Y")}"
      end
    elsif same_year?(delivery_start_date, delivery_end_date)
      # Same year - show month range
      if day_is_first_of_month?(delivery_start_date) && day_is_last_of_month?(delivery_end_date)
        "#{delivery_start_date.strftime("%B")} to #{delivery_end_date.strftime("%B %Y")}"
      else
        "#{format_date_for_timeframe(delivery_start_date)} to #{format_date_for_timeframe(delivery_end_date)}"
      end
    else
      # Different years
      if day_is_first_of_month?(delivery_start_date) && day_is_last_of_month?(delivery_end_date)
        "#{delivery_start_date.strftime("%B %Y")} to #{delivery_end_date.strftime("%B %Y")}"
      else
        "#{format_date_for_timeframe(delivery_start_date)} to #{format_date_for_timeframe(delivery_end_date)}"
      end
    end
  end

  private

  def format_date_for_timeframe(date)
    date.strftime("%B %-d, %Y")
  end

  def same_month?(date1, date2)
    date1.month == date2.month && date1.year == date2.year
  end

  def same_year?(date1, date2)
    date1.year == date2.year
  end

  def full_month?(start_date, end_date)
    day_is_first_of_month?(start_date) && day_is_last_of_month?(end_date)
  end

  def day_is_first_of_month?(date)
    date.day == 1
  end

  def day_is_last_of_month?(date)
    date.day == date.end_of_month.day
  end

  def delivery_end_date_after_start_date
    return unless delivery_start_date.present? && delivery_end_date.present?

    if delivery_end_date < delivery_start_date
      errors.add(:delivery_end_date, "cannot be before the start date")
    end
  end
end
