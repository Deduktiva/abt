WebAuthn.configure do |config|
  config.allowed_origins = [Settings.webauthn.origin]
  config.rp_name = Settings.webauthn.rp_name
  config.rp_id = Settings.webauthn.rp_id
  config.credential_options_timeout = 60_000
  config.algorithms = %w[ES256 RS256]
end
