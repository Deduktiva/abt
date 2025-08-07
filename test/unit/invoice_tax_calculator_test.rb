require 'test_helper'

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
      type: 'item',
      title: 'Product 1',
      description: 'First product',
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: @product_class,
      position: 1
    )

    line2 = @invoice.invoice_lines.create!(
      type: 'item',
      title: 'Product 2',
      description: 'Second product',
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
      type: 'item',
      title: 'Product',
      rate: 100.0,
      quantity: 1.0,
      sales_tax_product_class: @product_class,
      position: 1
    )

    text_line = @invoice.invoice_lines.create!(
      type: 'text',
      title: 'Note',
      description: 'A note',
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
      type: 'item',
      title: 'Product',
      rate: 100.0,
      quantity: 1.0,
      sales_tax_product_class_id: 99999, # Invalid ID
      position: 1
    )

    result = @invoice.validate_lines_for_booking

    assert_not result[:success], "Tax calculation should fail"
    assert_includes result[:errors], "no tax config for product class 99999"
  end

  test "has_items? returns true when invoice has item lines" do
    @invoice.invoice_lines.create!(
      type: 'item',
      title: 'Product',
      rate: 100.0,
      quantity: 1.0,
      sales_tax_product_class: @product_class,
      position: 1
    )

    assert @invoice.has_items?
  end

  test "has_items? returns false when invoice has no item lines" do
    @invoice.invoice_lines.create!(
      type: 'text',
      title: 'Note',
      description: 'Just a note',
      position: 1
    )

    assert_not @invoice.has_items?
  end

  test "clears existing tax classes before calculation" do
    # Create some existing tax classes
    @invoice.invoice_tax_classes.create!(
      sales_tax_product_class: @product_class,
      name: 'Old Tax',
      rate: 10.0,
      net: 100.0,
      total: 110.0
    )

    # Add an item line
    @invoice.invoice_lines.create!(
      type: 'item',
      title: 'Product',
      rate: 50.0,
      quantity: 1.0,
      sales_tax_product_class: @product_class,
      position: 1
    )

    @invoice.save

    # Old tax classes should be gone, new ones created
    @invoice.reload
    tax_classes = @invoice.invoice_tax_classes
    assert_not_empty tax_classes
    assert_not tax_classes.any? { |tc| tc.name == 'Old Tax' }
  end

  test "generates detailed log output" do
    @invoice.invoice_lines.create!(
      type: 'item',
      title: 'Test Product',
      description: 'Test Description',
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: @product_class,
      position: 1
    )

    result = @invoice.validate_lines_for_booking

    log = result[:log]
    assert_includes log, '--- BEGIN LINES ---'
    assert_includes log, '--- END LINES ---'
    assert log.any? { |line| line.include?('Test Product') }
    assert log.any? { |line| line.include?('Qty 2.0 * 100.0 = 200.0') }
  end

  test "validates successfully with mixed line types" do
    # Create mixed lines: subheading, items, and text
    @invoice.invoice_lines.create!(
      type: 'subheading',
      title: 'Phase 1: Setup',
      position: 1
    )

    @invoice.invoice_lines.create!(
      type: 'item',
      title: 'Project Setup',
      description: 'Initial setup work',
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: @product_class,
      position: 2
    )

    @invoice.invoice_lines.create!(
      type: 'text',
      title: 'Phase 1 completed successfully',
      description: 'All deliverables approved',
      position: 3
    )

    @invoice.invoice_lines.create!(
      type: 'item',
      title: 'Documentation',
      description: 'Technical documentation',
      rate: 75.0,
      quantity: 1.0,
      sales_tax_product_class: @product_class,
      position: 4
    )

    result = @invoice.validate_lines_for_booking

    assert result[:success], "Validation should succeed with mixed line types"
    assert_empty result[:errors], "Should have no errors: #{result[:errors]}"
    assert @invoice.has_items?, "Invoice should have items"
  end
end
