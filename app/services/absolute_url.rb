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
end
