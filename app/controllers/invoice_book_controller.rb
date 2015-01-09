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
      @invoice.due_date = @invoice.date + 30.days
    end

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
    @invoice.tax_classes = {}

    customer_sales_tax_rates.each do |cst|
      pc = cst.sales_tax_product_class
      @invoice.tax_classes[pc.id] = {
        :name => pc.name,
        :indicator_code => pc.indicator_code,
        :rate => cst.rate,
        :net => 0,
        :total => 0
      }
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

        error "no tax config for product class #{line.sales_tax_product_class_id}" if @invoice.tax_classes[line.sales_tax_product_class_id].nil?

        line.sales_tax_name = @invoice.tax_classes[line.sales_tax_product_class_id][:name]
        line.sales_tax_rate = @invoice.tax_classes[line.sales_tax_product_class_id][:rate]
        line.sales_tax_indicator_code = @invoice.tax_classes[line.sales_tax_product_class_id][:indicator_code]

        @invoice.tax_classes[line.sales_tax_product_class_id][:net] += line.amount
      else
        line.amount = nil
        line.rate = nil
        line.quantity = nil
      end
    end
    @log << '--- END LINES ---'
    @log << ''

    @log << 'Sums:'
    @invoice.sum_net = 0
    @invoice.sum_total = 0
    @invoice.tax_classes.each do |tc_id, tax_class|
      tax_class[:value] = tax_class[:net] * (tax_class[:rate]/100.0)
      tax_class[:total] = tax_class[:net] + tax_class[:value]
      @invoice.sum_net += tax_class[:net]
      @invoice.sum_total += tax_class[:total]
      @log << "TAX #{tax_class[:name]}/#{tax_class[:indicator_code]}: #{tax_class[:rate]}% of #{tax_class[:net]} = #{tax_class[:value]}"
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
      @invoice.attachment.filename = "Invoice-#{@invoice.document_number}.pdf"
      @invoice.attachment.title = "Invoice #{@invoice.document_number}"
      @invoice.attachment.save!
      @invoice.save!
    end

    !@failed
  end
end
