class OfferMilestone < ApplicationRecord
  belongs_to :offer_version
  belongs_to :invoice, optional: true
  belongs_to :delivery_note, optional: true

  enum :trigger, {
    on_order: "on_order",
    on_acceptance: "on_acceptance",
    on_date: "on_date"
  }, prefix: :trigger

  validates :title, presence: true
  validates :net_amount, presence: true,
                         numericality: { greater_than_or_equal_to: 0 }
  validates :trigger_date, presence: true, if: :trigger_on_date?
  validate :linked_invoice_or_delivery_note_unique

  # Default skip_delivery_note based on the trigger: order-time milestones
  # typically don't need a separate delivery note (the order itself is the
  # delivery signal), so we pre-check the box. acceptance- and date-triggered
  # milestones default to producing both a delivery note and an invoice.
  before_validation :default_skip_delivery_note_from_trigger, on: :create

  def converted?
    invoice_id.present? || delivery_note_id.present?
  end

  private

  def default_skip_delivery_note_from_trigger
    return unless skip_delivery_note.nil?
    self.skip_delivery_note = trigger_on_order?
  end

  # Defence in depth on top of the partial-unique indexes: surface a friendly
  # validation error if the in-process write would collide.
  def linked_invoice_or_delivery_note_unique
    if invoice_id.present? &&
       OfferMilestone.where(invoice_id: invoice_id).where.not(id: id).exists?
      errors.add(:invoice_id, "is already linked to another milestone")
    end
    if delivery_note_id.present? &&
       OfferMilestone.where(delivery_note_id: delivery_note_id).where.not(id: id).exists?
      errors.add(:delivery_note_id, "is already linked to another milestone")
    end
  end
end
