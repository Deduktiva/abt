# Shared human-facing naming for the parallel document types (Invoice,
# DeliveryNote).
module DocumentIdentity
  extend ActiveSupport::Concern

  # Identifier without a type prefix — the document number once published, or a
  # "Draft #id" stand-in while still a draft. Used wherever the surrounding
  # context (column header, breadcrumb chain) already names the document type.
  def display_label
    document_number || "Draft ##{id}"
  end

  # Same identifier with the model name in front, e.g. "Invoice 20240017" or
  # "Delivery Note Draft #42". Used in cross-references, modal titles, PDF
  # attachment names, and the browser <title> tag.
  def display_name
    "#{self.class.model_name.human} #{display_label}"
  end
end
