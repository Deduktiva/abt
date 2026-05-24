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
end
