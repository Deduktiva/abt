require "builder"

class OfferRenderer
  def initialize(version, issuer)
    @version = version
    @offer = version.offer
    @issuer = issuer
  end

  def emit_xml(logo_file_path)
    frozen = @version.frozen?
    customer = @offer.customer

    recipient_name = frozen ? @version.customer_name : customer.name
    recipient_address = frozen ? @version.customer_address : customer.address
    recipient_country = frozen ? @version.customer_country_iso2 : customer.country_iso2
    supplier_number = frozen ? @version.customer_supplier_number : customer.supplier_number
    payment_terms = frozen ? @version.payment_terms_days : customer.payment_terms_days
    boilerplate =
      if frozen
        @version.boilerplate.presence && @version.boilerplate
      else
        customer.offer_boilerplate.presence && customer.offer_boilerplate
      end
    date = @version.date || Date.current
    valid_until = frozen ? @offer.expires_at : Date.current + @offer.validity_days

    issuer_country = @issuer.country_iso2
    locale = customer.language.iso_code

    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct! :xml, encoding: "UTF-8", version: "1.0"

    xml.document class: "offer", "xmlns:fo" => "http://www.w3.org/1999/XSL/Format" do |xml_root|
      xml_root.language locale
      xml_root.tag! "accent-color", @issuer.document_accent_color
      xml_root.tag! "footer", @issuer.offer_footer

      if logo_file_path
        xml_root.tag! "logo-path", logo_file_path
        xml_root.tag! "logo-width", @issuer.pdf_logo_width
        xml_root.tag! "logo-height", @issuer.pdf_logo_height
      end

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
        xml_issuer.tag! "contact-line1", @issuer.document_contact_line1
        xml_issuer.tag! "contact-line2", @issuer.document_contact_line2
      end

      xml_root.recipient do |xml_recipient|
        xml_recipient.address AddressFormatter.build(
          name: recipient_name,
          address: recipient_address,
          self_country: recipient_country,
          other_country: issuer_country,
          locale: locale
        )
        xml_recipient.tag! "supplier-no", supplier_number if supplier_number.present?
      end

      xml_root.currency @issuer.currency
      xml_root.tag! "money-decimal-places", @issuer.money_decimal_places
      xml_root.subject @version.subject
      xml_root.number @offer.document_number.presence || "DRAFT"
      xml_root.tag! "issue-date", date.iso8601
      xml_root.tag! "valid-until", valid_until.iso8601
      xml_root.tag! "version-number", @version.version_number if @version.version_number >= 2
      xml_root.tag! "delivery-date", @version.delivery_date&.iso8601
      xml_root.tag! "payment-terms-days", payment_terms

      xml_root.prelude do |xml_prelude|
        xml_prelude << RichTextFoConverter.new(@version.prelude.body&.to_html).to_fo_fragment if @version.prelude.present?
      end
      xml_root.boilerplate do |xml_boilerplate|
        xml_boilerplate << RichTextFoConverter.new(boilerplate.body&.to_html).to_fo_fragment if boilerplate
      end

      xml_root.milestones do |xml_milestones|
        @version.milestones.each do |milestone|
          xml_milestones.milestone do |xml_milestone|
            xml_milestone.title milestone.title
            xml_milestone.description milestone.description
            xml_milestone.trigger milestone.trigger
            xml_milestone.tag! "trigger-date", milestone.trigger_date&.iso8601
            xml_milestone.amount milestone.amount
          end
        end
      end
    end

    xml.target!
  end

  def render
    logo_data = @issuer.pdf_logo.present? ? @issuer.pdf_logo : nil
    FopRenderer.new.render_pdf_with_logo("offer.xsl", logo_data) do |logo_file_path|
      emit_xml(logo_file_path)
    end
  end
end
