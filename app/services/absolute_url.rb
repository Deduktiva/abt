module AbsoluteUrl
  module_function

  def options
    {
      host: Settings.app.host,
      protocol: Settings.app.protocol,
      script_name: Settings.app.script_name
    }
  end

  def invite(token)
    Rails.application.routes.url_helpers.invite_url(token: token, **options)
  end

  def account_email_confirmation(token)
    Rails.application.routes.url_helpers.account_email_confirmation_url(token: token, **options)
  end

  def customer(customer)
    Rails.application.routes.url_helpers.customer_url(customer, **options)
  end

  def customer_portal_host_options
    options.merge(host: Settings.customer_portal.host.presence || Settings.app.host)
  end

  def delivery_acceptance_upload(token)
    Rails.application.routes.url_helpers.delivery_acceptance_upload_url(token: token, **customer_portal_host_options)
  end

  def delivery_note(dn)
    Rails.application.routes.url_helpers.delivery_note_url(dn, **options)
  end

  def offer(offer)
    Rails.application.routes.url_helpers.offer_url(offer, **options)
  end
end
