class InvoiceBooker
  attr_reader :log

  def initialize(invoice, issuer)
    @invoice = invoice
    @issuer = issuer
    @log = []
  end

  # Idempotent prep: refresh customer snapshot and invoice_tax_classes via
  # before_save callbacks, then assign date defaults in-memory. Safe to call
  # from preview (inside a rollback transaction) or before publishing.
  def prepare!
    return if @invoice.published?
    @invoice.save
    @invoice.date ||= Date.today
    @invoice.due_date = @invoice.date + @invoice.payment_terms_days.days
  end

  # Performs the irreversible booking. Returns true on success, false otherwise.
  # On failure, problems are accessible via @invoice.booking_problems.
  def publish!
    if @invoice.published?
      @log << "E: already published"
      return false
    end

    prepare!

    problems = @invoice.booking_problems
    if problems.any?
      problems.each { |p| @log << "E: #{p}" }
      return false
    end

    @invoice.invoice_lines.each(&:save!)
    @invoice.document_number ||= DocumentNumber.get_next_for("invoice", @invoice.date)
    @log << "Assigned Document Number #{@invoice.document_number}"
    @invoice.token = SecureRandom.base58(13)
    @invoice.published = true
    @invoice.save!

    pdf = InvoiceRenderer.new(@invoice, @issuer).render
    @invoice.attachment ||= Attachment.new
    @invoice.attachment.set_data(pdf, "application/pdf")
    @invoice.attachment.filename = "#{@issuer.short_name}-Invoice-#{@invoice.document_number}.pdf"
    @invoice.attachment.title = "#{@issuer.short_name} Invoice #{@invoice.document_number}"
    @invoice.attachment.save!
    @invoice.save!
    true
  end
end
