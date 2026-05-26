module DocumentWithLines
  extend ActiveSupport::Concern

  class_methods do
    # Configure the line class used by set_form_options.
    #
    #   document_with_lines line_class: InvoiceLine
    def document_with_lines(line_class:)
      @document_line_class = line_class
    end

    attr_reader :document_line_class
  end

  protected

  def set_form_options
    @line_type_options = self.class.document_line_class::TYPE_OPTIONS.to_a
  end

  # Filter: redirect with a flash if the document doesn't yet have at least
  # one item line. Without this, the renderer hands FOP a table with no
  # body and FOP aborts; this is also the business rule for publishing
  # a meaningful document.
  #
  # Relies on PublishableDocument for the record lookup and human label,
  # and on the model including HasLineItems for `has_items?`.
  def require_item_line
    record = publishable_record
    unless record.has_items?
      flash[:error] = "Cannot proceed with a #{self.class.publishable_label} that has no item lines."
      redirect_to record
      return false
    end
    true
  end
end
