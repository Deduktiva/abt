require "test_helper"

class InvoiceTaxCalculationTest < ActiveSupport::TestCase
  def setup
    @customer = customers(:good_national)
    @project = projects(:test_project)
    @product_class = sales_tax_product_classes(:standard)

    @invoice = Invoice.create!(
      customer: @customer,
      project: @project,
      cust_reference: "TEST-REF"
    )
  end

  test "calculates taxes correctly for invoice with item lines" do
    # Create item lines
    line1 = @invoice.invoice_lines.create!(
      type: "item",
      title: "Product 1",
      description: "First product",
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: @product_class,
      position: 1
    )

    line2 = @invoice.invoice_lines.create!(
      type: "item",
      title: "Product 2",
      description: "Second product",
      rate: 50.0,
      quantity: 1.0,
      sales_tax_product_class: @product_class,
      position: 2
    )

    # Check line amounts were calculated
    line1.reload
    line2.reload
    assert_equal 200.0, line1.amount
    assert_equal 50.0, line2.amount

    @invoice.save  # does most of the relevant work
    @invoice.reload

    # Check tax classes were created
    assert_not_empty @invoice.invoice_tax_classes
    tax_class = @invoice.invoice_tax_classes.first
    assert_equal 250.0, tax_class.net # 200 + 50

    # Check invoice totals
    assert_equal 250.0, @invoice.sum_net
    assert_equal 300.0, @invoice.sum_total  # national: 20% → 250 + 50 tax = 300
  end

  test "handles text lines correctly by clearing amounts" do
    # Create mixed lines
    @invoice.invoice_lines.create!(
      type: "item",
      title: "Product",
      rate: 100.0,
      quantity: 1.0,
      sales_tax_product_class: @product_class,
      position: 1
    )

    text_line = @invoice.invoice_lines.create!(
      type: "text",
      title: "Note",
      description: "A note",
      rate: 50.0,  # This should be cleared
      quantity: 2.0,  # This should be cleared
      amount: 100.0,  # This should be cleared
      position: 2
    )

    text_line.reload
    assert_nil text_line.rate
    assert_nil text_line.quantity
    assert_equal 0.0, text_line.amount
  end

  test "reports errors for missing tax configuration" do
    # Create item line with invalid product class
    @invoice.invoice_lines.create!(
      type: "item",
      title: "Product",
      rate: 100.0,
      quantity: 1.0,
      sales_tax_product_class_id: 99999, # Invalid ID
      position: 1
    )

    problems = @invoice.booking_problems

    assert(problems.any? { |p| p.include?("Product") && p.include?("tax configuration") },
           "Expected booking_problems to flag missing tax config, got: #{problems.inspect}")
  end

  test "has_items? returns true when invoice has item lines" do
    @invoice.invoice_lines.create!(
      type: "item",
      title: "Product",
      rate: 100.0,
      quantity: 1.0,
      sales_tax_product_class: @product_class,
      position: 1
    )

    assert @invoice.has_items?
  end

  test "has_items? returns false when invoice has no item lines" do
    @invoice.invoice_lines.create!(
      type: "text",
      title: "Note",
      description: "Just a note",
      position: 1
    )

    assert_not @invoice.has_items?
  end

  test "does not duplicate tax classes when saving an invoice with multiple item lines" do
    # Building several item lines via nested attributes used to recurse through
    # line_addedremoved → update_sums → setup_tax_classes on an unsaved parent
    # and create one InvoiceTaxClass row per line for the same product class.
    invoice = Invoice.new(customer: @customer, project: @project, cust_reference: "DUP-TEST")
    invoice.invoice_lines_attributes = [
      { type: "item", title: "L1", quantity: 1, rate: 100, sales_tax_product_class_id: @product_class.id },
      { type: "item", title: "L2", quantity: 2, rate: 50,  sales_tax_product_class_id: @product_class.id },
      { type: "item", title: "L3", quantity: 1, rate: 75,  sales_tax_product_class_id: @product_class.id }
    ]
    invoice.save!
    invoice.reload

    assert_equal 1, invoice.invoice_tax_classes.size
    itc = invoice.invoice_tax_classes.first
    assert_equal @product_class.id, itc.sales_tax_product_class_id
    assert_equal 275.0, itc.net # 100 + 100 + 75
    assert_equal 275.0, invoice.sum_net
  end

  test "refreshes stale name/rate on existing tax classes when product class changes" do
    # @invoice was auto-set-up with one InvoiceTaxClass for @product_class.
    # Simulate the product class metadata changing after the invoice exists,
    # and verify the next update_sums pass picks up the new values.
    itc = @invoice.invoice_tax_classes.find_by!(sales_tax_product_class: @product_class)
    original_rate = itc.rate

    @product_class.update!(name: "Renamed Goods", indicator_code: "RNM")

    @invoice.invoice_lines.create!(
      type: "item",
      title: "Product",
      rate: 50.0,
      quantity: 1.0,
      sales_tax_product_class: @product_class,
      position: 1
    )
    @invoice.save!

    itc.reload
    assert_equal "Renamed Goods", itc.name
    assert_equal "RNM", itc.indicator_code
    assert_equal original_rate, itc.rate
    assert_equal 50.0, itc.net
  end

  test "validates successfully with mixed line types" do
    # Create mixed lines: subheading, items, and text
    @invoice.invoice_lines.create!(
      type: "subheading",
      title: "Phase 1: Setup",
      position: 1
    )

    @invoice.invoice_lines.create!(
      type: "item",
      title: "Project Setup",
      description: "Initial setup work",
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: @product_class,
      position: 2
    )

    @invoice.invoice_lines.create!(
      type: "text",
      title: "Phase 1 completed successfully",
      description: "All deliverables approved",
      position: 3
    )

    @invoice.invoice_lines.create!(
      type: "item",
      title: "Documentation",
      description: "Technical documentation",
      rate: 75.0,
      quantity: 1.0,
      sales_tax_product_class: @product_class,
      position: 4
    )

    assert_empty @invoice.booking_problems
    assert @invoice.has_items?, "Invoice should have items"
  end
end
