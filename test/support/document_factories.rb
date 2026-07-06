module DocumentFactories
  # Drafts default to the fixture pair customer/project combo that most tests
  # already use. Override anything as a kwarg.

  def build_draft_invoice(**overrides)
    Invoice.new({
      customer: customers(:good_eu),
      project:  projects(:test_project)
    }.merge(overrides))
  end

  def create_draft_invoice(**overrides)
    build_draft_invoice(**overrides).tap(&:save!)
  end

  def create_invoice_with_item_line(rate: 100.0, quantity: 2.0,
                                    sales_tax_product_class: sales_tax_product_classes(:standard),
                                    line_overrides: {}, **invoice_overrides)
    invoice = create_draft_invoice(**invoice_overrides)
    invoice.invoice_lines.create!({
      type: "item",
      title: "Test Product",
      rate: rate,
      quantity: quantity,
      sales_tax_product_class: sales_tax_product_class,
      position: 1
    }.merge(line_overrides))
    invoice
  end

  def build_draft_delivery_note(**overrides)
    DeliveryNote.new({
      customer: customers(:good_eu),
      project:  projects(:one),
      delivery_start_date: Date.current
    }.merge(overrides))
  end

  def create_draft_delivery_note(**overrides)
    build_draft_delivery_note(**overrides).tap(&:save!)
  end

  def create_delivery_note_with_item_line(quantity: 1.0, line_overrides: {}, **note_overrides)
    note = create_draft_delivery_note(**note_overrides)
    note.delivery_note_lines.create!({
      type: "item",
      title: "Test Item",
      quantity: quantity,
      position: 1
    }.merge(line_overrides))
    note
  end

  def create_draft_offer(customer: customers(:good_eu), project: projects(:one))
    Offer.create!(customer: customer, project: project)
  end

  def create_offer_with_milestone(**kwargs)
    offer = create_draft_offer(**kwargs)
    offer.draft_version.update!(subject: "Offer subject")
    offer.draft_version.milestones.create!(title: "Milestone", amount: 1000, trigger: "on_acceptance", position: 1)
    offer
  end

  def create_published_delivery_note(customer: customers(:good_eu), document_number:, cust_reference:,
                                     project: projects(:one), **overrides)
    DeliveryNote.new({
      customer: customer,
      project: project,
      document_number: document_number,
      published: true,
      date: Date.current,
      cust_reference: cust_reference,
      delivery_start_date: Date.current,
      delivery_note_lines_attributes: [
        { type: "item", title: "Item", description: "desc", quantity: 1.0, position: 1 }
      ]
    }.merge(overrides)).tap(&:save!)
  end
end
