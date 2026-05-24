class DeliveryNoteMailer < ApplicationMailer
  def customer_email
    @delivery_note = params[:delivery_note]
    attach_pdf(@delivery_note)

    customer = @delivery_note.customer
    to = subject = nil

    I18n.with_locale(customer.language.iso_code) do
      if customer.email.present?
        subject = I18n.t('mailers.delivery_note.subject', issuer_name: @issuer.short_name, document_number: @delivery_note.document_number)
        to = customer.email
      end

      document_mail(to: to, subject: subject)
    end
  end

  def bulk_customer_email
    @delivery_notes = params[:delivery_notes]
    @customer = @delivery_notes.first.customer

    @delivery_notes.each { |dn| attach_pdf(dn) }

    customer = @customer
    to = subject = nil

    I18n.with_locale(customer.language.iso_code) do
      if customer.email.present?
        document_numbers = @delivery_notes.map(&:document_number).join(', ')
        subject = I18n.t('mailers.delivery_note.bulk_subject', issuer_name: @issuer.short_name, document_numbers: document_numbers)
        to = customer.email
      end

      document_mail(to: to, subject: subject)
    end
  end

  private

  def attach_pdf(delivery_note)
    pdf_data = DeliveryNoteRenderer.new(delivery_note, @issuer).render
    attachments["#{@issuer.short_name}-DeliveryNote-#{delivery_note.document_number}.pdf"] = {
      mime_type: 'application/pdf',
      content: pdf_data
    }
  end
end
