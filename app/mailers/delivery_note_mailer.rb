class DeliveryNoteMailer < ApplicationMailer
  def customer_email
    @delivery_note = params[:delivery_note]
    attach_pdf(@delivery_note) unless params[:skip_attachments]

    customer = @delivery_note.customer
    to = @delivery_note.email_recipients

    with_customer_locale(customer) do
      subject = I18n.t("mailers.delivery_note.subject", issuer_name: @issuer.short_name, document_number: @delivery_note.document_number)
      document_mail(to: to, subject: subject)
    end
  end

  # Caller must ensure every delivery note in @delivery_notes resolves to the
  # same `recipients` set, otherwise we'd leak one DN's recipients onto
  # another. DeliveryNotesController#bulk_send_emails partitions accordingly
  # by [customer_id, sorted recipient list].
  def bulk_customer_email
    @delivery_notes = params[:delivery_notes]
    @customer = @delivery_notes.first.customer
    to = params[:recipients] || @customer.contacts_for_delivery_note(@delivery_notes.first).map(&:email)

    @delivery_notes.each { |dn| attach_pdf(dn) }

    with_customer_locale(@customer) do
      document_numbers = @delivery_notes.map(&:document_number).join(", ")
      subject = I18n.t("mailers.delivery_note.bulk_subject", issuer_name: @issuer.short_name, document_numbers: document_numbers)
      document_mail(to: to, subject: subject)
    end
  end

  private

  def attach_pdf(delivery_note)
    pdf_data = DeliveryNoteRenderer.new(delivery_note, @issuer).render
    attachments["#{@issuer.short_name}-DeliveryNote-#{delivery_note.document_number}.pdf"] = {
      mime_type: "application/pdf",
      content: pdf_data
    }
  end
end
