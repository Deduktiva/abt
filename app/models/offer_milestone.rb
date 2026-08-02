class OfferMilestone < ApplicationRecord
  class NotReopenable < StandardError; end

  TRIGGERS = %w[on_order on_acceptance on_date].freeze
  TRIGGER_LABELS = {
    "on_order" => "Upon order",
    "on_acceptance" => "Upon acceptance",
    "on_date" => "On date"
  }.freeze

  belongs_to :offer_version
  delegate :offer, to: :offer_version
  belongs_to :invoice, optional: true
  belongs_to :delivery_note, optional: true

  validates :title, presence: true
  validates :amount, presence: true, numericality: true
  validates :trigger, presence: true, inclusion: { in: TRIGGERS }
  validates :trigger_date, presence: true, if: -> { trigger == "on_date" }
  validates :invoice_id, uniqueness: true, allow_nil: true
  validates :delivery_note_id, uniqueness: true, allow_nil: true

  after_save :refresh_version_sum
  after_destroy :refresh_version_sum

  def trigger_label
    label = TRIGGER_LABELS.fetch(trigger, trigger)
    trigger == "on_date" && trigger_date ? "#{label} #{I18n.l(trigger_date)}" : label
  end

  def converted?
    invoice_id.present?
  end

  def default_skip_delivery_note
    trigger == "on_order"
  end

  def link_reopenable?
    !invoice&.published? && !delivery_note&.published?
  end

  def reopen_link!
    raise NotReopenable, "linked invoice is already published" if invoice&.published?
    raise NotReopenable, "linked delivery note is already published" if delivery_note&.published?
    update!(invoice: nil, delivery_note: nil)
  end

  private

  def refresh_version_sum
    offer_version.recalculate_sum_net!
  end
end
