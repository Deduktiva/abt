# Matches requests for the authenticated app, i.e. every host except the public
# customer portal host. Returns true when no customer portal host is configured
# (single-host / portal disabled), so the app stays reachable everywhere.
class AppHostConstraint
  def matches?(request)
    host = Settings.customer_portal&.host.presence
    return true if host.blank?
    request.host != host
  end
end
