class OfferMilestoneConverter
  class NotConvertible < StandardError; end

  def initialize(milestone)
    @milestone = milestone
    @version = milestone.offer_version
    @offer = @version.offer
  end

  def convert!
    raise NotConvertible, "offer is not accepted" unless @offer.accepted?
    raise NotConvertible, "milestone belongs to a non-accepted version" unless @version.id == @offer.accepted_version_id
    raise NotConvertible, "milestone already converted" if @milestone.converted?

    ActiveRecord::Base.transaction do
      invoice = build_invoice
      invoice.save!
      delivery_note = @milestone.skip_delivery_note? ? nil : build_delivery_note(invoice).tap(&:save!)
      @milestone.update!(invoice: invoice, delivery_note: delivery_note)
      invoice
    end
  end

  private

  # The offer's internal reference carries over; with several milestones each
  # document gets the milestone's ordinal appended so they stay tellable apart.
  def internal_reference
    ordinal = @version.milestones.index(@milestone) + 1 if @version.milestones.many?
    [ @offer.internal_reference.presence, ordinal ].compact.join(" ").presence
  end

  # A delivery date predating the order date would fail the delivery-note
  # date-range validation; the admin sets the range on the draft instead.
  def delivery_end_date
    date = @version.delivery_date
    date if date.present? && date >= @offer.ordered_on
  end

  def line_title
    @version.subject.presence || @milestone.title
  end

  def line_description
    reference =
      if @offer.customer.language&.iso_code == "de"
        "Angebot Nummer #{@offer.document_number} v#{@version.version_number}"
      else
        "Offer #{@offer.document_number} v#{@version.version_number}"
      end
    [ @milestone.title, reference, @milestone.description.presence ].compact.join("\n")
  end

  def build_invoice
    invoice = Invoice.new(customer: @offer.customer, project: @offer.project,
                          cust_order: @offer.order_number,
                          internal_reference: internal_reference)
    invoice.prelude = @version.prelude.body.to_html if @version.prelude.present?
    invoice.invoice_lines.build(type: "item", position: 1, title: line_title,
                                description: line_description, quantity: 1,
                                rate: @milestone.amount,
                                sales_tax_product_class_id: @version.sales_tax_product_class_id)
    invoice
  end

  def build_delivery_note(invoice)
    dn = DeliveryNote.new(customer: @offer.customer, project: @offer.project,
                          invoice: invoice, cust_order: @offer.order_number,
                          internal_reference: internal_reference,
                          delivery_start_date: @offer.ordered_on,
                          delivery_end_date: delivery_end_date)
    dn.delivery_note_lines.build(type: "item", position: 1, title: line_title,
                                 description: line_description, quantity: 1)
    dn
  end
end
