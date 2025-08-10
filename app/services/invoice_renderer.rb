require 'builder'

class InvoiceRenderer

  def initialize(invoice, issuer)
    @invoice = invoice
    @issuer = issuer
    @fop_renderer = FopRenderer.new
  end

  def emit_xml(xml, logo_file_path)
    xml.instruct! :xml, :encoding => 'UTF-8', :version => '1.0'

    xml.document :class => 'invoice' do |xml_invoice|
      xml_invoice.tag! 'accent-color', @issuer.document_accent_color
      xml_invoice.tag! 'footer', @issuer.invoice_footer

      # Add logo information if available
      if logo_file_path
        xml_invoice.tag! 'logo-path', logo_file_path
        xml_invoice.tag! 'logo-width', @issuer.pdf_logo_width
        xml_invoice.tag! 'logo-height', @issuer.pdf_logo_height
      end
      xml_invoice.issuer do |xml_issuer|
        xml_issuer.address @issuer.legal_name + "\n" + @issuer.address
        xml_issuer.tag! 'short-name', @issuer.short_name
        xml_issuer.tag! 'legal-name', @issuer.legal_name
        xml_issuer.tag! 'vat-id', @issuer.vat_id
        xml_issuer.tag! 'contact-line1', @issuer.document_contact_line1
        xml_issuer.tag! 'contact-line2', @issuer.document_contact_line2
        xml_issuer.bankaccount do |tag|
          tag.tag! 'bank', @issuer.bankaccount_bank
          tag.tag! 'bic', @issuer.bankaccount_bic
          tag.tag! 'number', @issuer.bankaccount_number
        end
      end

      xml_invoice.recipient do |xml_recipient|
        xml_recipient.tag! 'order-no', @invoice.cust_order
        xml_recipient.reference @invoice.cust_reference

        xml_recipient.address @invoice.customer_name + "\n" + @invoice.customer_address
        xml_recipient.tag! 'account-no', @invoice.customer_account_number
        xml_recipient.tag! 'vat-id', @invoice.customer_vat_id
        xml_recipient.tag! 'supplier-no', @invoice.customer_supplier_number
      end

      xml_invoice.currency 'EUR'
      xml_invoice.prelude @invoice.prelude
      xml_invoice.tag! 'tax-note', @invoice.tax_note
      xml_invoice.number @invoice.document_number
      xml_invoice.tag! 'issue-date', @invoice.date
      xml_invoice.tag! 'due-date', @invoice.due_date
      if @invoice.published
        if @invoice.token.nil?
          payment_url = ''
        else
          payment_url = Settings.payments.public_url.gsub('%token%', @invoice.token)
        end
      else
        payment_url = Settings.payments.public_url.gsub('%token%', 'NOT-YET-ASSIGNED')
      end

      xml_invoice.tag! 'payment-url', payment_url

      xml_invoice.items do |xml_items|
        @invoice.invoice_lines.each do |line|
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
              xml_item.rate line.rate
              xml_item.amount line.amount
              xml_item.tag! 'tax-class', line.sales_tax_indicator_code
            end
          end
        end
      end

      Rails.logger.debug @invoice.invoice_tax_classes.inspect
      Rails.logger.debug "len: #{@invoice.invoice_tax_classes.length}"

      xml_invoice.sums do |xml_sums|
        xml_sums.tag! 'tax-classes' do |xml_tax_classes|
          @invoice.invoice_tax_classes.all.each do |tax_class|
            xml_tax_classes.tag! 'tax-class', {:name => tax_class.name, 'indicator-code' => tax_class.indicator_code} do |xml_tax_class|
              xml_tax_class.percentage tax_class.rate
              xml_tax_class.sum tax_class.net
              xml_tax_class.value tax_class.value
            end
          end
        end
        xml_sums.net @invoice.sum_net
        xml_sums.total @invoice.sum_total
      end

    end
  end

  def render
    Rails.logger.info "InvoiceRenderer#render"

    logo_data = @issuer.pdf_logo.present? ? @issuer.pdf_logo : nil
    @fop_renderer.render_pdf_with_logo(logo_data) do |logo_file_path|
      generate_xml_string(logo_file_path)
    end
  end

  private

  def generate_xml_string(logo_file_path)
    xml_string = ""
    xml = Builder::XmlMarkup.new(:target => xml_string, :indent => 2)
    emit_xml(xml, logo_file_path)
    xml_string
  end
end
