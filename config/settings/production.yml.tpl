# Production settings template
# Copy to production.yml and configure for your environment

fop:
  binary_path: "./bin/abt-fop"

payments:
  public_url: "https://example.com/payments/%token%"

app:
  host: 'example.com'
  protocol: 'https'

customer_portal:
  host: 'customer-portal.example.com'

webauthn:
  rp_name: 'ABT'
  rp_id: 'example.com'
  origin: 'https://example.com'
