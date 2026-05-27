# ABT Apache VirtualHost template.
#
# Copy to /etc/apache2/sites-available/abt.conf, edit ServerName, SSL paths,
# and log paths to match the host, then `a2ensite abt && systemctl reload apache2`.
# The app-owned directives are kept in deploy/apache/abt-app.conf inside the
# repo so they stay in sync with the application.

<VirtualHost *:443>
  ServerName abt.example.com

  ErrorLog  /var/log/apache2/abt_error_ssl.log
  CustomLog /var/log/apache2/abt_access_ssl.log combined
  ServerSignature Off

  SSLEngine on
  SSLCertificateFile    /etc/apache2/ssl/abt.crt
  SSLCertificateKeyFile /etc/apache2/ssl/abt.key

  Include /srv/abt/deploy/apache/abt-app.conf
</VirtualHost>
