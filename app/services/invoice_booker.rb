class InvoiceBooker
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

    # trigger before_save callbacks which populate customer fields
    @invoice.save

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

    # Calculate taxes
    line_validation_result = @invoice.validate_lines_for_booking

    # Add calculator logs and errors to our log
    @log.concat(line_validation_result[:log])
    line_validation_result[:errors].each { |err| error(err) }

    unless @invoice.has_items?
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
      pdf = InvoiceRenderer.new(@invoice, @issuer).render
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
