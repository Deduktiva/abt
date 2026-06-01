# Matches requests whose Host is the configured public customer portal host.
# Returns false when no customer portal host is configured, so the constrained
# route block simply isn't mounted (public flow disabled).
class CustomerPortalHostConstraint
  def matches?(request)
    host = Settings.customer_portal&.host.presence
    return false if host.blank?
    request.host == host
  end
end
