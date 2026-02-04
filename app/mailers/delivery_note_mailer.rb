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
      # Use customer contacts that should receive delivery notes for this project
      recipients = get_delivery_note_recipients(@delivery_note)
      if recipients.any?
        subject = I18n.t('mailers.delivery_note.subject', issuer_name: @issuer.short_name, document_number: @delivery_note.document_number)
        to = recipients
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
      # Use customer contacts that should receive delivery notes
      recipients = get_bulk_delivery_note_recipients(@customer, @delivery_notes)
      if recipients.any?
        document_numbers = @delivery_notes.map(&:document_number).join(', ')
        subject = I18n.t('mailers.delivery_note.bulk_subject', issuer_name: @issuer.short_name, document_numbers: document_numbers)
        to = recipients
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

  private

  # Get email recipients for delivery note delivery based on customer contacts
  def get_delivery_note_recipients(delivery_note)
    # For now, delivery notes go to all contacts that receive invoices
    # When delivery note flags are added to customer contacts, update this logic
    delivery_note.customer.customer_contacts
               .select { |contact| contact.receives_invoices_for_project?(delivery_note.project) }
               .map(&:email)
  end

  # Get email recipients for bulk delivery note delivery
  def get_bulk_delivery_note_recipients(customer, delivery_notes)
    # For bulk delivery, get contacts that can receive delivery notes for any of the projects
    projects = delivery_notes.map(&:project).uniq
    customer.customer_contacts
            .select { |contact|
              contact.receives_invoices? && (
                contact.projects.empty? ||
                (contact.projects & projects).any?
              )
            }
            .map(&:email)
            .uniq
  end
end
