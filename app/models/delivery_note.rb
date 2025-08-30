class DeliveryNote < ApplicationRecord
  validates :customer_id, :presence => true
  validates :delivery_start_date, :presence => true
  validate :delivery_end_date_after_start_date
  default_scope { order(Arel.sql("id ASC")) }

  scope :email_sent, -> { where.not(email_sent_at: nil) }
  scope :email_unsent, -> {
    joins(customer: :customer_contacts)
    .where(email_sent_at: nil)
    .where(customer_contacts: { receives_invoices: true })
    .distinct
  }
  scope :published, -> { where(published: true) }

  belongs_to :customer
  belongs_to :project
  belongs_to :acceptance_attachment, class_name: 'Attachment', :optional => true
  belongs_to :invoice, :optional => true

  has_many :delivery_note_lines, -> { order(:position, :id) }, dependent: :delete_all
  accepts_nested_attributes_for :delivery_note_lines, allow_destroy: true, reject_if: :all_blank

  def publish!
    return if self.published?

    self.date = Date.today
    if self.document_number.nil?
      self.document_number = DocumentNumber.get_next_for 'delivery_note', self.date
    end
    self.published = true
    self.save!
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
