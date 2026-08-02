require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

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

    # SCSS sources are compiled by dartsass into app/assets/builds; keep the
    # raw sources out of Propshaft. Must be set here, not in an initializer —
    # Propshaft applies excluded_paths in its engine initializer, which runs
    # before config/initializers.
    config.assets.excluded_paths << Rails.root.join("app/assets/stylesheets")

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

    # Active Storage exists only as ActionText plumbing; the rich-text editor
    # blocks attachments (rich_text_controller.js), and document PDFs use the
    # custom Attachment model. Disable variants so no image-processing stack
    # (image_processing, ruby-vips/libvips, ImageMagick) is needed.
    config.active_storage.variant_processor = :disabled

    # Nothing attaches files, so don't expose the built-in endpoints. They are
    # drawn outside the host constraints in config/routes.rb and inherit from
    # ActiveStorage::BaseController, so unauthenticated callers could otherwise
    # POST /rails/active_storage/direct_uploads and PUT the returned
    # disk-service token to write arbitrary bytes to the storage root.
    # ActionText computes rich_text_area's upload URLs from these routes —
    # ApplicationHelper#rich_text_field supplies blank ones instead.
    config.active_storage.draw_routes = false

    # Route Solid Queue's ActiveRecord models to the dedicated queue database
    # in all environments so the jobs status page can read them.
    config.solid_queue.connects_to = { database: { writing: :queue } }

    # db/schema.rb is owned by the SQLite development lane. Migrating any other
    # environment against PostgreSQL (bin/postgres-dev, CI's test env) would
    # otherwise rewrite it in PostgreSQL dialect, which SQLite then can't load.
    config.active_record.dump_schema_after_migration = Rails.env.development?
  end
end
