# To silence Phusion's phone-home checks (anonymous telemetry logs
# spurious "End time can not be before or equal to begin time" notices;
# the security update checker logs a "no update found" line every 24h),
# set these in the global Apache server context (not inside a VirtualHost):
#   PassengerDisableAnonymousTelemetry on
#   PassengerDisableSecurityUpdateCheck on

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
