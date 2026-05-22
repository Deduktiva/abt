# Production settings template
# Copy to production.yml and configure for your environment

fop:
  binary_path: "./script/abt-fop"

payments:
  public_url: "https://your-domain.com/payments/%token%"

webauthn:
  # Must exactly match the scheme + host (+ port if non-default) that
  # browsers see. WebAuthn rejects assertions where the origin does not
  # match. The app refuses to boot if this is blank.
  origin: "https://your-domain.com"
  rp_name: "ABT"
