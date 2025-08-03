class InvoiceBookController
  attr_reader :log, :failed

  def initialize(invoice, issuer)
    @invoice = invoice
    @issuer = issuer
    @failed = false
    @log = []
  end

  def error(msg)
    @failed = true
    @log << "E: #{msg}"
  end

  def empty_or_nil(obj)
    return true if obj.nil?
    return true if obj.empty?
    false
  end

  def book(save)
    if @invoice.published?
      error 'already published'
      return !@failed
    end

    @invoice.customer_name = @invoice.customer.name
    @invoice.customer_address = @invoice.customer.address
    @invoice.customer_account_number = @invoice.customer.id
    @invoice.customer_supplier_number = @invoice.customer.supplier_number
    @invoice.customer_vat_id = @invoice.customer.vat_id
    @invoice.tax_note = @invoice.customer.sales_tax_customer_class.invoice_note
    if @invoice.date.nil?
      @invoice.date = Date.today
    end
    @invoice.due_date = @invoice.date + @invoice.customer.payment_terms_days.days

    error 'no customer name' if empty_or_nil @invoice.customer_name
    error 'no customer address' if empty_or_nil @invoice.customer_address
    error 'no customer vat id' if empty_or_nil @invoice.customer_vat_id
    @log << "Customer: #{@invoice.customer_name}, #{@invoice.customer_address.gsub("\n", ', ').gsub("\r", '')}"
    @log << "  VATID: #{@invoice.customer_vat_id}"
    @log << "Customer Order No: #{@invoice.cust_order}, Cust. Reference: #{@invoice.cust_reference}"
    @log << "Customer's supplier no: #{@invoice.customer_supplier_number}"
    @log << ''
    @log << "Prelude: #{@invoice.prelude}"
    @log << ''

    customer_sales_tax_rates = @invoice.customer.sales_tax_rates
    if customer_sales_tax_rates.nil?
      error 'no sales tax config for customer'
      return !@failed
    end

    @invoice.invoice_tax_classes.all.each do |tax_class| tax_class.destroy! end
    customer_sales_tax_rates.each do |cst|
      data = ActionController::Parameters.new({
        sales_tax_product_class: cst.sales_tax_product_class,
        name: cst.sales_tax_product_class.name,
        indicator_code: cst.sales_tax_product_class.indicator_code,
        rate: cst.rate,
        net: 0,
        total: 0
      }).permit!
      @invoice.invoice_tax_classes.create! data
    end

    have_an_item = false
    @log << '--- BEGIN LINES ---'

    @invoice.invoice_lines.each do |line|
      @log << "#{line.id}.  #{line.type} #{line.title} #{line.description}"

      if line.type == 'item'
        have_an_item = true
        error "no quantity on line id #{line.id}" if line.quantity.nil?
        error "no rate on line id #{line.id}" if line.rate.nil?
        line.amount = line.quantity * line.rate
        @log << "#{line.id}.     Qty #{line.quantity} * #{line.rate} = #{line.amount}"

        itc = @invoice.invoice_tax_classes.find_by_sales_tax_product_class_id(line.sales_tax_product_class_id)
        error "no tax config for product class #{line.sales_tax_product_class_id}" if itc.nil?

        line.sales_tax_name = itc.name
        line.sales_tax_rate = itc.rate
        line.sales_tax_indicator_code = itc.indicator_code

        itc.net += line.amount
        itc.save!
      else
        line.amount = nil
        line.rate = nil
        line.quantity = nil
      end
      Rails.logger.debug "line: #{line.inspect}"
      line.save!
    end
    @log << '--- END LINES ---'
    @log << ''

    @log << 'Sums:'
    @invoice.sum_net = 0
    @invoice.sum_total = 0
    @invoice.invoice_tax_classes.all.each do |itc|
      @invoice.sum_net += itc.net
      @invoice.sum_total += itc.total
      @log << "TAX #{itc.name}/#{itc.indicator_code}: #{itc.rate}% of #{itc.net} = #{itc.value}"
    end
    @log << "== SUM: Net: #{@invoice.sum_net}, Total: #{@invoice.sum_total}"

    unless have_an_item
      error 'not even one item line'
    end

    if !@failed and save
      @invoice.invoice_lines.each do |line| line.save! end
      if @invoice.document_number.nil?
        @invoice.document_number = DocumentNumber.get_next_for 'invoice', @invoice.date
      end
      @log << "Assigned Document Number #{@invoice.document_number}"
      @invoice.token = Rfc4648Base32.i_to_s((SecureRandom.random_number(100).to_s + (@invoice.customer.id + 100000).to_s + @invoice.document_number.to_s).to_i)
      @invoice.published = true
      @invoice.save!

      # render as well
      pdf = InvoiceRenderController.new(@invoice, @issuer).render
      @invoice.attachment = Attachment.new if @invoice.attachment.nil?
      @invoice.attachment.set_data pdf, 'application/pdf'
      @invoice.attachment.filename = "#{@issuer.short_name}-Invoice-#{@invoice.document_number}.pdf"
      @invoice.attachment.title = "#{@issuer.short_name} Invoice #{@invoice.document_number}"
      @invoice.attachment.save!
      @invoice.save!
    end

    !@failed
  end
end
