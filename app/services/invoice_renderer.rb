require "builder"

class InvoiceRenderer
  def initialize(invoice, issuer)
    @invoice = invoice
    @issuer = issuer
  end

  def emit_xml(logo_file_path)
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct! :xml, encoding: "UTF-8", version: "1.0"

    xml.document class: "invoice", "xmlns:fo" => "http://www.w3.org/1999/XSL/Format" do |xml_root|
      xml_root.language @invoice.customer.language.iso_code
      xml_root.tag! "accent-color", @issuer.document_accent_color
      xml_root.tag! "footer", @issuer.invoice_footer

      # Add logo information if available
      if logo_file_path
        xml_root.tag! "logo-path", logo_file_path
        xml_root.tag! "logo-width", @issuer.pdf_logo_width
        xml_root.tag! "logo-height", @issuer.pdf_logo_height
      end
      issuer_country = @issuer.country_iso2
      recipient_country = @invoice.customer_country_iso2
      locale = @invoice.customer.language.iso_code

      xml_root.issuer do |xml_issuer|
        xml_issuer.address AddressFormatter.build(
          name: @issuer.legal_name,
          address: @issuer.address,
          self_country: issuer_country,
          other_country: recipient_country,
          locale: locale
        )
        xml_issuer.tag! "short-name", @issuer.short_name
        xml_issuer.tag! "legal-name", @issuer.legal_name
        xml_issuer.tag! "vat-id", @issuer.vat_id
        xml_issuer.tag! "contact-line1", @issuer.document_contact_line1
        xml_issuer.tag! "contact-line2", @issuer.document_contact_line2
        xml_issuer.bankaccount do |tag|
          tag.tag! "bank", @issuer.bankaccount_bank
          tag.tag! "bic", @issuer.bankaccount_bic
          tag.tag! "number", @issuer.bankaccount_number
        end
      end

      xml_root.recipient do |xml_recipient|
        xml_recipient.tag! "order-no", @invoice.cust_order
        xml_recipient.reference @invoice.cust_reference

        xml_recipient.address AddressFormatter.build(
          name: @invoice.customer_name,
          address: @invoice.customer_address,
          self_country: recipient_country,
          other_country: issuer_country,
          locale: locale
        )
        xml_recipient.tag! "account-no", @invoice.customer_account_number
        xml_recipient.tag! "vat-id", @invoice.customer_vat_id
        xml_recipient.tag! "supplier-no", @invoice.customer_supplier_number if @invoice.customer_supplier_number.present?
      end

      xml_root.currency "EUR"
      xml_root.tag! "money-decimal-places", @issuer.money_decimal_places
      xml_root.prelude do |xml_prelude|
        xml_prelude << RichTextFoConverter.new(@invoice.prelude.body&.to_html).to_fo_fragment if @invoice.prelude.present?
      end
      xml_root.tag! "tax-note", @invoice.tax_note
      xml_root.number @invoice.document_number
      xml_root.tag! "issue-date", @invoice.date
      xml_root.tag! "due-date", @invoice.due_date
      xml_root.tag! "payment-terms-days", @invoice.payment_terms_days
      if @invoice.published
        if @invoice.token.nil?
          payment_url = ""
        else
          payment_url = Settings.payments.public_url.gsub("%token%", @invoice.token)
        end
      else
        payment_url = Settings.payments.public_url.gsub("%token%", "NOT-YET-ASSIGNED")
      end

      xml_root.tag! "payment-url", payment_url

      xml_root.items do |xml_items|
        @invoice.invoice_lines.each do |line|
          if line.type == "text"
            xml_items.text do |xml_item|
              xml_item.title line.title
              xml_item.description line.description if line.description
            end
          elsif line.type == "plain"
            xml_items.text do |xml_item|
              xml_item.title line.title
              xml_item.plain line.description if line.description
            end
          elsif line.type == "subheading"
            xml_items.subheading do |xml_item|
              xml_item.title line.title
            end
          elsif line.type == "item"
            xml_items.item do |xml_item|
              xml_item.title line.title
              xml_item.description line.description if line.description
              xml_item.quantity line.quantity
              xml_item.rate line.rate
              xml_item.amount line.amount
              xml_item.tag! "tax-class", line.sales_tax_indicator_code
            end
          end
        end
      end

      xml_root.sums do |xml_sums|
        xml_sums.tag! "tax-classes" do |xml_tax_classes|
          @invoice.invoice_tax_classes.all.each do |tax_class|
            xml_tax_classes.tag! "tax-class", { :name => tax_class.name, "indicator-code" => tax_class.indicator_code } do |xml_tax_class|
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

    xml.target!
  end

  def render
    logo_data = @issuer.pdf_logo.present? ? @issuer.pdf_logo : nil
    FopRenderer.new.render_pdf_with_logo("invoice.xsl", logo_data) do |logo_file_path|
      emit_xml(logo_file_path)
    end
  end
end
