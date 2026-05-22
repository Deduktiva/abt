origin = Settings.webauthn&.origin

if origin.blank?
  raise "WebAuthn origin is not configured. Set `webauthn.origin` in " \
        "config/settings/#{Rails.env}.yml — must match the scheme + host " \
        "+ port that browsers see (e.g. https://abt.example.com)."
end

WebAuthn.configure do |config|
  config.allowed_origins = [origin]
  config.rp_name = Settings.webauthn&.rp_name || "ABT"
  config.encoding = :base64url
end
