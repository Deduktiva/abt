ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  next if event.payload[:exception_object]

  job = event.payload[:job]
  next unless job.is_a?(ActionMailer::MailDeliveryJob)

  mailer_name, _action, _delivery, opts = job.arguments
  params = opts.is_a?(Hash) ? (opts[:params] || {}) : {}
  now = Time.current

  case mailer_name
  when "InvoiceMailer"
    params[:invoice]&.update_column(:email_sent_at, now)
  when "DeliveryNoteMailer"
    if (dn = params[:delivery_note])
      dn.update_column(:email_sent_at, now)
    elsif (dns = params[:delivery_notes])
      DeliveryNote.where(id: dns.map(&:id)).update_all(email_sent_at: now)
    end
  end
end
