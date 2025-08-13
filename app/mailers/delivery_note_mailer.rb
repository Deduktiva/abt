class DeliveryNoteMailer < ApplicationMailer
  def customer_email
    @delivery_note = params[:delivery_note]
    @issuer = IssuerCompany.get_the_issuer!

    # Generate and attach the PDF
    pdf_data = DeliveryNoteRenderer.new(@delivery_note, @issuer).render
    attachments["#{@issuer.short_name}-DeliveryNote-#{@delivery_note.document_number}.pdf"] = {
      mime_type: 'application/pdf',
      content: pdf_data
    }

    # Set locale based on customer language
    I18n.with_locale(@delivery_note.customer.language.iso_code) do
      if @delivery_note.customer.email.present?
        subject = I18n.t('mailers.delivery_note.subject', issuer_name: @issuer.short_name, document_number: @delivery_note.document_number)
        to = @delivery_note.customer.email
      else
        to = nil
      end

      unless to.nil?
        mail(
          to: to,
          from: "\"#{@issuer.short_name}\" <#{@issuer.document_email_from}>",
          bcc: @issuer.document_email_auto_bcc,
          subject: subject
        )
      end
    end
  end

  def bulk_customer_email
    @delivery_notes = params[:delivery_notes]
    @customer = @delivery_notes.first.customer
    @issuer = IssuerCompany.get_the_issuer!

    # Generate and attach PDFs for each delivery note
    @delivery_notes.each do |delivery_note|
      pdf_data = DeliveryNoteRenderer.new(delivery_note, @issuer).render
      attachments["#{@issuer.short_name}-DeliveryNote-#{delivery_note.document_number}.pdf"] = {
        mime_type: 'application/pdf',
        content: pdf_data
      }
    end

    # Set locale based on customer language
    I18n.with_locale(@customer.language.iso_code) do
      if @customer.email.present?
        document_numbers = @delivery_notes.map(&:document_number).join(', ')
        subject = I18n.t('mailers.delivery_note.bulk_subject', issuer_name: @issuer.short_name, document_numbers: document_numbers)
        to = @customer.email
      else
        to = nil
      end

      unless to.nil?
        mail(
          to: to,
          from: "\"#{@issuer.short_name}\" <#{@issuer.document_email_from}>",
          bcc: @issuer.document_email_auto_bcc,
          subject: subject
        )
      end
    end
  end
end
