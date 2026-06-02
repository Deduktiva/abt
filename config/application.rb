require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Abt
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Modern Permissions-Policy header (Rails 8 still emits Feature-Policy).
    require_relative "../app/middleware/permissions_policy_header"
    config.middleware.use PermissionsPolicyHeader

    # Discourage search-engine indexing on every response. The layout's
    # `robots` meta tag only covers HTML; this header also protects the PDFs
    # (invoices, delivery notes) served through controllers.
    config.action_dispatch.default_headers =
      config.action_dispatch.default_headers.merge("X-Robots-Tag" => "noindex, nofollow")

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.

    config.action_mailer.delivery_method = :mailgun
    config.action_mailer.mailgun_settings = Rails.application.credentials.mailgun

    # Route Solid Queue's ActiveRecord models to the dedicated queue database
    # in all environments so the jobs status page can read them.
    config.solid_queue.connects_to = { database: { writing: :queue } }
  end
end
