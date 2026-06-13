# Read-only health checks surfaced on the dashboard for admins. Each returns
# zero or one Issue. Pure: the live request context (host/protocol/script_name)
# is injected, so the checks are testable without a real request.
class DashboardConsistencyChecks
  include Rails.application.routes.url_helpers

  Issue = Struct.new(:key, :title, :details, :fix_path, :fix_label, keyword_init: true)

  def initialize(host:, protocol:, script_name:)
    @host = host
    @protocol = protocol
    @script_name = script_name
  end

  def issues
    [ admin_permissions_issue, absolute_url_issue ].compact
  end

  private

  # The Admin group's permissions are frozen into a migration snapshot, so a
  # newly-added Permission key only reaches existing installs via a follow-up
  # data migration (or db:seed). This catches the gap if one is ever missed.
  def admin_permissions_issue
    admin = Group.admin
    return nil unless admin

    missing = Permission::ALL_KEYS - admin.permissions
    return nil if missing.empty?

    Issue.new(
      key: :admin_permissions,
      title: "Admin group is missing permissions",
      details: missing.map { |key| Permission.label_for(key) },
      fix_path: edit_group_path(admin),
      fix_label: "Review Admin group permissions"
    )
  end

  # Absolute URLs baked into emails and tokens are built from Settings.app
  # (see AbsoluteUrl), independent of the request. If the configured values
  # drift from how the app is actually reached, those links break silently
  # while in-app browsing keeps working. Compare against the live request.
  def absolute_url_issue
    mismatches = []
    mismatches << url_line("Host", Settings.app.host, @host) unless host_match?
    mismatches << url_line("Protocol", Settings.app.protocol, @protocol) unless protocol_match?
    mismatches << url_line("Path prefix", Settings.app.script_name, @script_name) unless script_name_match?
    return nil if mismatches.empty?

    Issue.new(
      key: :absolute_url,
      title: "Link base URL doesn't match how you're accessing the app",
      details: [ "Links in emails and customer-portal tokens use the configured values below, not the address in your browser:" ] + mismatches
    )
  end

  def host_match?
    normalize_host(Settings.app.host) == normalize_host(@host)
  end

  def protocol_match?
    Settings.app.protocol.to_s.downcase == @protocol.to_s.downcase
  end

  def script_name_match?
    normalize_path(Settings.app.script_name) == normalize_path(@script_name)
  end

  def normalize_host(value)
    value.to_s.downcase.sub(/:\d+\z/, "")
  end

  def normalize_path(value)
    value.to_s.chomp("/")
  end

  def url_line(label, configured, actual)
    "#{label}: configured #{configured.to_s.inspect}, but you're using #{actual.to_s.inspect}"
  end
end
