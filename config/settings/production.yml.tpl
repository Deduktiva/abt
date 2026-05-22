# Production settings template
# Copy to production.yml and configure for your environment

fop:
  binary_path: "./script/abt-fop"

payments:
  public_url: "https://your-domain.com/payments/%token%"

app:
  host: 'your-domain.com'
  protocol: 'https'

webauthn:
  rp_name: 'ABT'
  rp_id: 'your-domain.com'
  origin: 'https://your-domain.com'
