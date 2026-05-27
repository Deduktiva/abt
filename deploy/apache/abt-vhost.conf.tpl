# ABT Apache VirtualHost template.
#
# Copy to /etc/apache2/sites-available/abt.conf, edit ServerName and log
# paths to match the host, then `a2ensite abt && systemctl reload apache2`.
# App-owned directives live in deploy/apache/abt-app.conf.
#
# Connections arrive via HAProxy using `send-proxy-v2`; mod_remoteip
# consumes the header to recover the real client IP. Anything that can
# reach this :443 listener and send a PROXY header can forge that IP —
# restrict :443 to the HAProxy ingress.
#
# mod_md handles ACME via TLS-ALPN-01 over the same :443 listener; HAProxy
# forwards the ClientHello (ALPN included) verbatim through SNI passthrough.
# No :80 vhost — HAProxy 301-redirects all HTTP traffic.

MDCertificateAgreement accepted
MDCAChallenges tls-alpn-01

<VirtualHost *:443>
  ServerName abt.example.com
  MDomain abt.example.com

  ErrorLog  /var/log/apache2/abt_error_ssl.log
  CustomLog /var/log/apache2/abt_access_ssl.log combined
  ServerSignature Off

  # Deliberately no `RemoteIPHeader` — only the PROXY-protocol header on
  # the TCP connection is trusted, never a client-supplied X-Forwarded-For.
  RemoteIPProxyProtocol On
  # Silence AH03507 from HAProxy health checks: trixie's Apache 2.4.67
  # mod_remoteip rejects PROXY-protocol LOCAL headers (mainline accepts).
  LogLevel remoteip:crit

  SSLEngine on

  Include /srv/abt/deploy/apache/abt-app.conf
</VirtualHost>
