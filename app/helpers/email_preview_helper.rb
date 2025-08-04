module EmailPreviewHelper
  # Extracts email preview data from ActionMailer::MessageDelivery or Mail::Message
  def extract_email_preview_data(mail)
    data = {
      to: mail.to&.join(', '),
      from: mail.from&.first,
      subject: mail.subject,
      html_body: extract_html_body(mail),
      text_body: extract_text_body(mail),
      attachments: extract_attachments_info(mail)
    }

    data[:bcc] = mail.bcc&.join(', ') if mail.bcc&.any?
    data
  end

  private

  def extract_html_body(mail)
    if mail.multipart?
      mail.html_part&.body&.decoded
    else
      mail.content_type&.include?('text/html') ? mail.body.decoded : nil
    end
  end

  def extract_text_body(mail)
    if mail.multipart?
      mail.text_part&.body&.decoded
    else
      mail.content_type&.include?('text/plain') ? mail.body.decoded : nil
    end
  end

  def extract_attachments_info(mail)
    mail.attachments.map do |attachment|
      {
        filename: attachment.filename,
        content_type: attachment.content_type,
        size: attachment.body.raw_source.bytesize
      }
    end
  end
end
