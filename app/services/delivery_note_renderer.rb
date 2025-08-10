require 'builder'

class DeliveryNoteRenderer

  def initialize(delivery_note, issuer)
    @delivery_note = delivery_note
    @issuer = issuer
  end

  def emit_xml(logo_file_path)
    xml = Builder::XmlMarkup.new(:indent => 2)
    xml.instruct! :xml, :encoding => 'UTF-8', :version => '1.0'

    xml.document :class => 'delivery_note' do |xml_root|
      xml_root.language @delivery_note.customer.language.iso_code
      xml_root.tag! 'accent-color', @issuer.document_accent_color

      # Add logo information if available
      if logo_file_path
        xml_root.tag! 'logo-path', logo_file_path
        xml_root.tag! 'logo-width', @issuer.pdf_logo_width
        xml_root.tag! 'logo-height', @issuer.pdf_logo_height
      end
      xml_root.issuer do |xml_issuer|
        xml_issuer.address @issuer.legal_name + "\n" + @issuer.address
        xml_issuer.tag! 'short-name', @issuer.short_name
        xml_issuer.tag! 'legal-name', @issuer.legal_name
        xml_issuer.tag! 'vat-id', @issuer.vat_id
        xml_issuer.tag! 'contact-line1', @issuer.document_contact_line1
        xml_issuer.tag! 'contact-line2', @issuer.document_contact_line2
      end

      xml_root.recipient do |xml_recipient|
        xml_recipient.tag! 'order-no', @delivery_note.cust_order
        xml_recipient.reference @delivery_note.cust_reference

        xml_recipient.address @delivery_note.customer.name + "\n" + @delivery_note.customer.address
        xml_recipient.tag! 'account-no', @delivery_note.customer.id
        xml_recipient.tag! 'vat-id', @delivery_note.customer.vat_id
        xml_recipient.tag! 'supplier-no', @delivery_note.customer.supplier_number
      end

      xml_root.prelude @delivery_note.prelude
      xml_root.number @delivery_note.document_number
      xml_root.tag! 'issue-date', @delivery_note.date || '2999-01-01'
      xml_root.tag! 'delivery-timeframe', @delivery_note.delivery_timeframe if @delivery_note.delivery_timeframe.present?

      xml_root.items do |xml_items|
        @delivery_note.delivery_note_lines.each do |line|
          if line.type == 'text'
            xml_items.text do |xml_item|
              xml_item.title line.title
              xml_item.description line.description if line.description
            end
          elsif line.type == 'plain'
            xml_items.text do |xml_item|
              xml_item.title line.title
              xml_item.plain line.description if line.description
            end
          elsif line.type == 'subheading'
            xml_items.subheading do |xml_item|
              xml_item.title line.title
            end
          elsif line.type == 'item'
            xml_items.item do |xml_item|
              xml_item.title line.title
              xml_item.description line.description if line.description
              xml_item.quantity line.quantity
            end
          end
        end
      end
    end

    xml.target!
  end

  def render
    logo_data = @issuer.pdf_logo.present? ? @issuer.pdf_logo : nil
    FopRenderer.new.render_pdf_with_logo('delivery_note.xsl', logo_data) do |logo_file_path|
      emit_xml(logo_file_path)
    end
  end
end
