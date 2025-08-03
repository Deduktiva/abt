<VirtualHost *:443>
  ServerName abt

  ## Vhost docroot
  DocumentRoot "/srv/abt/public"

  ## Directories, there should at least be a declaration for /srv/abt/public

  PassengerEnabled on
  PassengerAppEnv production
  SetENV FOP_EXTRA_JAR_PATH /srv/fop-extra-jars

  ## Logging
  ErrorLog "/var/log/apache2/abt_error_ssl.log"
  ServerSignature Off
  CustomLog "/var/log/apache2/abt_access_ssl.log" combined

  ## SSL directives
  SSLEngine on
  SSLCertificateFile      "/etc/apache2/ssl/abt.crt"
  SSLCertificateKeyFile   "/etc/apache2/ssl/abt.key"
</VirtualHost>

