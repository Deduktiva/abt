# Rails 8 still emits the deprecated `Feature-Policy` header for
# `config.permissions_policy`. Modern browsers expect the renamed
# `Permissions-Policy` header (different syntax: `name=(allow-list)`),
# so this middleware emits it alongside Rails's output.
#
# Keep the directive list in sync with config/initializers/permissions_policy.rb.
class PermissionsPolicyHeader
  POLICY = [
    "camera=()",
    "microphone=()",
    "geolocation=()",
    "gyroscope=()",
    "magnetometer=()",
    "accelerometer=()",
    "usb=()",
    "payment=()",
    "fullscreen=(self)"
  ].join(", ").freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    headers["Permissions-Policy"] ||= POLICY
    [status, headers, body]
  end
end
