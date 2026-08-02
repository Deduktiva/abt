class DeliveryNoteInvoiceConverter
  include LockedConversion

  def initialize(delivery_note)
    @delivery_note = delivery_note
  end

  private

  def conversion_source = @delivery_note

  def convert_locked!
    raise NotConvertible, "delivery note already converted" if @delivery_note.invoice_id.present?

    invoice = Invoice.new(customer: @delivery_note.customer, project: @delivery_note.project,
                          cust_reference: @delivery_note.cust_reference,
                          cust_order: @delivery_note.cust_order,
                          internal_reference: @delivery_note.internal_reference,
                          prelude: prelude)
    invoice.save!
    default_product_class_id = SalesTaxProductClass.default&.id
    @delivery_note.delivery_note_lines.each do |line|
      InvoiceLine.create!(line_attributes(line, invoice, default_product_class_id))
    end
    @delivery_note.update!(invoice: invoice)
    invoice
  end

  def prelude
    reference_line = I18n.with_locale(@delivery_note.customer.language.iso_code) do
      I18n.t("invoice_conversion.reference_line",
             number: @delivery_note.display_label,
             date: I18n.l(@delivery_note.date))
    end

    html = ActionController::Base.helpers.simple_format(reference_line)
    html += @delivery_note.prelude.body.to_html if @delivery_note.prelude.present?
    html
  end

  # Built as plain attributes and inserted directly, bypassing the line
  # callbacks that recompute invoice sums per line.
  def line_attributes(line, invoice, default_product_class_id)
    attrs = {
      invoice_id: invoice.id,
      type: line.type,
      title: line.title,
      description: line.description,
      position: line.position
    }

    if line.type == "item"
      attrs[:quantity] = (line.quantity&.to_f || 1.0).to_f
      # Leave the rate blank: delivery notes carry no prices, and a blank rate
      # blocks publishing until the user enters a real price.
      attrs[:sales_tax_product_class_id] = default_product_class_id
    else
      attrs[:amount] = 0
    end

    attrs
  end
end
