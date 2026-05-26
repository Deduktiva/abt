module HasLineItems
  extend ActiveSupport::Concern

  class_methods do
    # Configure which has_many association holds the document's lines.
    #
    #   has_line_items :invoice_lines
    def has_line_items(association)
      @line_items_association = association
    end

    attr_reader :line_items_association
  end

  # At least one line of type 'item' (as opposed to text / subheading /
  # plain). Required for publishing taxes / totals and for the document to
  # carry meaningful content.
  def has_items?
    public_send(self.class.line_items_association).any?(&:is_item?)
  end
end
