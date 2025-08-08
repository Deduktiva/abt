require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Abt
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    config.action_mailer.delivery_method = :mailgun
    config.action_mailer.mailgun_settings = Rails.application.credentials.mailgun

    # Support for subdirectory deployment (e.g., /abt/ behind reverse proxy)
    if ENV['RAILS_RELATIVE_URL_ROOT']
      config.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT']
    elsif ENV['X_FORWARDED_PREFIX']
      config.relative_url_root = ENV['X_FORWARDED_PREFIX']
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
