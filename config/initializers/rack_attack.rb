# Rate-limits unauthenticated endpoints to mitigate brute-force probing and
# DoS attacks targeting the CPU-heavy WebAuthn verification path.
#
# Notes on resilience:
# - Counters live in Rails.cache (solid_cache) in all environments including
#   tests. A cache-DB outage means EVERY request 500s, including /up - this
#   is intentional: the load balancer will mark the instance unhealthy and
#   stop sending traffic, instead of silently disabling rate limiting.
# - IPv6 addresses are bucketed by /64 to prevent free-address-rotation
#   bypass (a single /64 holds 2**64 unique addresses).
# - Client IP comes from ActionDispatch::RemoteIp (configured via
#   `config.action_dispatch.trusted_proxies`) rather than Rack::Request#ip,
#   which has surprising X-Forwarded-For chain-walking behavior behind
#   RFC1918 proxies.

require 'ipaddr'

class Rack::Attack
  self.cache.store = Rails.cache

  # --- Client identification ---

  def self.client_ip(req)
    (req.env['action_dispatch.remote_ip'] || req.ip).to_s
  end

  def self.ip_key(req)
    ip = IPAddr.new(client_ip(req))
    ip.ipv6? ? ip.mask(64).to_s : ip.to_s
  rescue IPAddr::InvalidAddressError, IPAddr::Error
    client_ip(req)
  end

  # Whether the request carries a validly-signed session cookie. Does not
  # verify the session is still active server-side; that is the controller's
  # job. The cookie was minted by us after a successful WebAuthn login, so an
  # attacker cannot forge one without our signing key.
  def self.authenticated_request?(req)
    ActionDispatch::Request.new(req.env)
      .cookie_jar.signed[ApplicationController::SESSION_COOKIE].present?
  rescue StandardError
    false
  end

  # --- Throttles ---

  # WebAuthn verify is the heaviest unauthenticated operation (curve crypto,
  # COSE parsing, attestation). Strict per-/64 budget.
  throttle('webauthn-verify/ip', limit: 10, period: 1.minute) do |req|
    next nil unless req.post?
    if req.path == '/session/verify' ||
       req.path.match?(%r{\A/invites/[^/]+/verify\z})
      ip_key(req)
    end
  end

  # General unauthenticated auth-related POSTs.
  throttle('auth-post/ip', limit: 30, period: 1.minute) do |req|
    next nil unless req.post?
    if req.path.match?(%r{\A/session/(options|verify)\z}) ||
       req.path.match?(%r{\A/invites/[^/]+/(options|verify)\z})
      ip_key(req)
    end
  end

  # GET /session/new — explicit per-/64 limit so a single attacker cannot
  # consume the whole 300/min backstop on the login page.
  throttle('session-new/ip', limit: 60, period: 1.minute) do |req|
    ip_key(req) if req.get? && req.path == '/session/new'
  end

  # Tokenized GETs.
  throttle('token-fetch/ip', limit: 60, period: 1.minute) do |req|
    next nil unless req.get?
    if req.path.match?(%r{\A/invites/[^/]+\z}) ||
       req.path.match?(%r{\A/account/email_confirmations/[^/]+\z})
      ip_key(req)
    end
  end

  # Backstop. Skips static assets and authenticated requests (signed session
  # cookie present) so a chatty SPA does not hit this limit. /up is NOT
  # exempted: see the file-level note above.
  throttle('req/ip', limit: 300, period: 1.minute) do |req|
    next nil if req.path.start_with?('/assets/')
    next nil if authenticated_request?(req)
    ip_key(req)
  end

  # --- Escalation ---

  # If an IP triggers 5 throttle violations within 10 minutes, ban it for an
  # hour. Counters are incremented from throttled_responder below.
  PERSISTENT_VIOLATOR_OPTIONS = {
    maxretry: 5, findtime: 10.minutes, bantime: 1.hour
  }.freeze

  blocklist('persistent-throttle') do |req|
    Rack::Attack::Allow2Ban.banned?("violator:#{ip_key(req)}")
  end

  # --- Response ---

  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data'] || {}
    retry_after = match_data[:period] || 60

    Rack::Attack::Allow2Ban.filter(
      "violator:#{ip_key(request)}",
      PERSISTENT_VIOLATOR_OPTIONS
    ) { true }

    accept = request.get_header('HTTP_ACCEPT').to_s
    wants_html = accept.include?('text/html') && !accept.include?('application/json')

    body, content_type =
      if wants_html
        ['<!DOCTYPE html><html><head><title>Too many requests</title></head>' \
         "<body><h1>Too many requests</h1>" \
         "<p>Please wait #{retry_after} seconds and try again.</p>" \
         '</body></html>',
         'text/html; charset=utf-8']
      else
        [{ error: 'Rate limit exceeded. Please try again later.' }.to_json,
         'application/json']
      end

    [
      429,
      {
        'content-type' => content_type,
        'cache-control' => 'no-store',
        'retry-after' => retry_after.to_s
      },
      [body]
    ]
  end
end

ActiveSupport::Notifications.subscribe(/rack_attack$/) do |name, _start, _finish, _id, payload|
  req = payload[:request]
  event = name.split('.').first
  Rails.logger.warn "[rack-attack] #{event} #{req.env['rack.attack.matched']} " \
                    "ip=#{Rack::Attack.client_ip(req)} path=#{req.path}"
end
