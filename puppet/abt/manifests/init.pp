# == Class: abt
#
# Full description of class abt here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { 'apache':
#    default_vhost => false,
#  }
#  class { 'abt':
#    vhost_name => 'abt.example.org',
#    vhost_port => 80,
#    postgresql_password => '123changeme',
#    install_path => '/srv/abt-example',
#  }
#
# === Authors
#
# Christian Hofstaedtler <hi@deduktiva.com>
#
# === Copyright
#
# Copyright 2014 Deduktiva GmbH
#
class abt(
  $vhost_name => undef,
  $vhost_port => 80,
  $postgresql_password => undef,
  $install_path => "/srv/abt",
) {
  include apache::mod::passenger

  $config_path = "${install_path}/config"
  $docroot = "${install_path}/public"
  file { $docroot:
    ensure => directory,
    owner => 'abt',
    group => 'abt',
  }

  apache::vhost { $vhost_name:
    port    => $vhost_post,
    docroot => $docroot,
    directories => [
      { path => $docroot,
        passenger_enabled => 'on',
        auth_type => 'Basic',
        auth_name => 'ABT',
        auth_require => 'valid-user',
        auth_user_file => '/etc/apache2/htauth.abt',
      },
    ]
  }

  file { "${config_path}/database.yml":
    owner => 'abt',
    group => 'abt',
    source => 'puppet:///modules/abt/database.yml.prod',
  }
  file { "${config_path}/initializers/secret_token.rb":
    ensure => absent,
  }
  file { "${config_path}/settings/production.yml":
    owner => 'abt',
    group => 'abt',
    source => 'puppet:///modules/abt/settings.yml.prod',
  }
  file { '/etc/apache2/htauth.abt':
    owner => 'root',
    group => 'www-data',
    mode => 0640,
    source => 'puppet:///modules/abt/htauth',
  }

  postgresql::server::db { 'abt':
    user => 'abt',
    password => postgresql_password('abt', $postgresql_password),
  }

  # for Rails assets compiler
  package { 'nodejs-legacy':
    ensure => installed,
  }

  include abt::fop
}
