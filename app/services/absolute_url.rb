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
end
