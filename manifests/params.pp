## Class: simp_grafana::params
#
# This class is meant to be called from simp_grafana.
# It sets variables according to platform.
#
# @private
#
class simp_grafana::params {

  $client_nets     = defined('$::client_nets')     ? { true => $::client_nets,     default => hiera('client_nets',     ['127.0.0.0/8']) }
  $enable_firewall = defined('$::enable_firewall') ? { true => $::enable_firewall, default => hiera('enable_firewall', true)            }
  $enable_pki      = defined('$::enable_pki')      ? { true => $::enable_pki,      default => hiera('enable_pki',      true)            }

  $admin_pw   = passgen('grafana')

  case $::osfamily {
    'RedHat': { }
    default: {
      fail("${::operatingsystem} not supported")
    }
  }

  # Static defaults
  $cfg = {
    server       => {
      http_port => 443,
      protocol  => 'https',
      cert_file => "/etc/grafana/pki/public/${::fqdn}.pub",
      cert_key  => "/etc/grafana/pki/private/${::fqdn}.pem",
    },
    security     => {
      admin_password   => $admin_pw,
      disable_gravatar => true,
    },
    users        => {
      allow_sign_up    => false,
      allow_org_create => true,
      auto_assign_org  => true,
    },
    'auth.basic' => { enabled => false },
    'auth.ldap'  => { enabled => false  },
  }
}
