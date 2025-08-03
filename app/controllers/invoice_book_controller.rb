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

    # Calculate taxes using the extracted service
    tax_calculator = InvoiceTaxCalculator.new(@invoice)
    tax_calculation_successful = tax_calculator.calculate!

    # Add calculator logs and errors to our log
    @log.concat(tax_calculator.log)
    tax_calculator.errors.each { |err| error(err) }

    unless tax_calculator.has_items?
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
