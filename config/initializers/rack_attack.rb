# Rate-limits unauthenticated endpoints to mitigate brute-force probing and
# DoS attacks targeting the CPU-heavy WebAuthn verification path.

class Rack::Attack
  # Use Rails.cache (solid_cache_store) in real environments so counters are
  # shared across processes. Use a per-process memory store in tests so
  # individual tests do not throttle each other.
  Rack::Attack.cache.store =
    if Rails.env.test?
      ActiveSupport::Cache::MemoryStore.new
    else
      Rails.cache
    end

  # WebAuthn options/verify are CPU-heavy and unauthenticated.
  # Throttle POSTs to /session/* and /invites/:token/* to 30 per minute per IP.
  throttle('auth-post/ip', limit: 30, period: 1.minute) do |req|
    next nil unless req.post?
    if req.path.start_with?('/session/') ||
       req.path.match?(%r{\A/invites/[^/]+/(options|verify)\z})
      req.ip
    end
  end

  # Tokenized GET endpoints. Throttle to 60 per minute per IP to limit
  # invite/confirmation token probing.
  throttle('token-fetch/ip', limit: 60, period: 1.minute) do |req|
    next nil unless req.get?
    if req.path.match?(%r{\A/invites/[^/]+\z}) ||
       req.path.match?(%r{\A/account/email_confirmations/[^/]+\z})
      req.ip
    end
  end

  # Backstop: cap any single IP to 300 requests per minute. Skip the health
  # check and static assets so they cannot exhaust the budget.
  throttle('req/ip', limit: 300, period: 1.minute) do |req|
    next nil if req.path == '/up' || req.path.start_with?('/assets/')
    req.ip
  end

  # Respond with JSON 429 plus a Retry-After header.
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data'] || {}
    retry_after = match_data[:period] || 60

    [
      429,
      {
        'content-type' => 'application/json',
        'retry-after' => retry_after.to_s
      },
      [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]
    ]
  end
end

ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn "[rack-attack] throttled #{req.env['rack.attack.matched']} ip=#{req.ip} path=#{req.path}"
end
