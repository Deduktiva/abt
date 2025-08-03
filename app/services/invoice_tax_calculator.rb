class InvoiceTaxCalculator
  attr_reader :errors, :log

  def initialize(invoice)
    @invoice = invoice
    @errors = []
    @log = []
  end

  def calculate!
    setup_tax_classes
    calculate_line_taxes
    calculate_totals

    return errors.empty?
  end

  def has_items?
    @invoice.invoice_lines.any? { |line| line.type == 'item' }
  end

private

  def setup_tax_classes
    customer_sales_tax_rates = @invoice.customer.sales_tax_rates
    if customer_sales_tax_rates.nil?
      @errors << 'no sales tax config for customer'
      return
    end

    # Get required product class IDs from customer tax rates
    required_product_class_ids = customer_sales_tax_rates.map(&:sales_tax_product_class_id).to_set

    # Get existing tax classes
    existing_tax_classes = @invoice.invoice_tax_classes.includes(:sales_tax_product_class).index_by(&:sales_tax_product_class_id)

    # Update/create required tax classes
    customer_sales_tax_rates.each do |cst|
      product_class_id = cst.sales_tax_product_class_id

      if existing_tax_classes[product_class_id]
        # Update existing tax class
        itc = existing_tax_classes[product_class_id]
        itc.update!({
          name: cst.sales_tax_product_class.name,
          indicator_code: cst.sales_tax_product_class.indicator_code,
          rate: cst.rate,
          net: 0,
          total: 0
        })
      else
        # Create new tax class
        @invoice.invoice_tax_classes.create!({
          sales_tax_product_class: cst.sales_tax_product_class,
          name: cst.sales_tax_product_class.name,
          indicator_code: cst.sales_tax_product_class.indicator_code,
          rate: cst.rate,
          net: 0,
          total: 0
        })
      end
    end

    # Delete tax classes that are no longer needed
    @invoice.invoice_tax_classes.where.not(sales_tax_product_class_id: required_product_class_ids).destroy_all
  end

  def calculate_line_taxes
    @log << '--- BEGIN LINES ---'

    @invoice.invoice_lines.each do |line|
      @log << "#{line.id}.  #{line.type} #{line.title} #{line.description}"

      should_save = true
      if line.type == 'item'
        should_save = process_item_line(line)
      else
        clear_non_item_line(line)
      end

      # Only save the line if processing was successful
      line.save!(validate: false) if should_save
    end

    @log << '--- END LINES ---'
    @log << ''
  end

  def process_item_line(line)
    if line.quantity.nil?
      @errors << "no quantity on line id #{line.id}"
      return false
    end

    if line.rate.nil?
      @errors << "no rate on line id #{line.id}"
      return false
    end

    line.amount = line.quantity * line.rate
    @log << "#{line.id}.     Qty #{line.quantity} * #{line.rate} = #{line.amount}"

    itc = @invoice.invoice_tax_classes.find_by_sales_tax_product_class_id(line.sales_tax_product_class_id)
    if itc.nil?
      @errors << "no tax config for product class #{line.sales_tax_product_class_id}"
      return false
    end

    line.sales_tax_name = itc.name
    line.sales_tax_rate = itc.rate
    line.sales_tax_indicator_code = itc.indicator_code

    current_net = itc.net || 0
    itc.net = current_net + line.amount
    itc.save!
    return true
  end

  def clear_non_item_line(line)
    line.amount = 0.0
    line.rate = nil
    line.quantity = nil
  end

  def calculate_totals
    @log << 'Sums:'
    @invoice.sum_net = 0
    @invoice.sum_total = 0

    @invoice.invoice_tax_classes.reload.each do |itc|
      @invoice.sum_net += itc.net
      @invoice.sum_total += itc.total
      @log << "TAX #{itc.name}/#{itc.indicator_code}: #{itc.rate}% of #{itc.net} = #{itc.value}"
    end

    @log << "== SUM: Net: #{@invoice.sum_net}, Total: #{@invoice.sum_total}"

    # Save without triggering callbacks that might override our calculations
    @invoice.update_columns(sum_net: @invoice.sum_net, sum_total: @invoice.sum_total)
  end
end