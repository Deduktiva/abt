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

  # Build (and persist) a draft Invoice (and optionally DeliveryNote) for this
  # milestone, link the FKs back, and return the new Invoice. The caller —
  # typically the UI's "Convert" action — chooses whether to skip the
  # delivery note via `skip_delivery_note:`. When `nil`, the milestone's
  # stored preset is used.
  def convert!(skip_delivery_note: nil)
    raise "milestone already converted" if converted?
    raise "offer is not in accepted state" unless offer_version.offer.state_accepted?

    skip_dn = skip_delivery_note.nil? ? self.skip_delivery_note : skip_delivery_note

    offer = offer_version.offer
    product_class = offer_version.sales_tax_product_class ||
                    SalesTaxProductClass.where(is_default: true).first

    line_attrs = {
      type: "item",
      title: title,
      description: description,
      quantity: 1,
      rate: net_amount,
      position: 0
    }

    transaction do
      if skip_dn
        invoice = Invoice.new(
          customer: offer.customer,
          project: offer.project,
          prelude: invoice_prelude_for(offer)
        )
        invoice.save!
        invoice.invoice_lines.create!(line_attrs.merge(sales_tax_product_class_id: product_class&.id))
        update!(invoice_id: invoice.id)
        invoice
      else
        raise "cannot create delivery note without a project" if offer.project.nil?
        dn = DeliveryNote.new(
          customer: offer.customer,
          project: offer.project,
          prelude: dn_prelude_for(offer),
          cust_reference: offer.document_number,
          delivery_start_date: offer_version.delivery_start_date || Date.current,
          delivery_end_date: offer_version.delivery_end_date
        )
        dn.save!
        dn.delivery_note_lines.create!(
          type: "item",
          title: title,
          description: description,
          quantity: 1,
          position: 0
        )
        invoice = Invoice.new(
          customer: offer.customer,
          project: offer.project,
          prelude: invoice_prelude_for(offer)
        )
        invoice.save!
        invoice.invoice_lines.create!(line_attrs.merge(sales_tax_product_class_id: product_class&.id))
        dn.update!(invoice_id: invoice.id)
        update!(invoice_id: invoice.id, delivery_note_id: dn.id)
        invoice
      end
    end
  end

  private

  def invoice_prelude_for(offer)
    [ "Based on offer #{offer.document_number} (#{offer.matchcode})", offer_version.prelude ].compact_blank.join("\n\n")
  end

  def dn_prelude_for(offer)
    "Based on offer #{offer.document_number} (#{offer.matchcode})"
  end

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
