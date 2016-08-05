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
  $use_ldap        = defined('$::use_ldap')        ? { true => $::use_ldap,        default => hiera('use_ldap',        false)           }

  $admin_pw = passgen('grafana')

  $base_dn = hiera('ldap::base_dn', 'dc=invalid')
  $bind_dn = hiera('ldap::bind_dn', "uid=%s,${base_dn}")
  $bind_pw = hiera('ldap::bind_pw', undef)

  $ldap_urls   = hiera_array('ldap::uri', [''])
  $ldap_url    = $ldap_urls[0]
  $ldap_server = inline_template(
    '<%= @ldap_url.match(/(([[:alnum:]][[:alnum:]-]{0,254})?[[:alnum:]]\.)+(([[:alnum:]][[:alnum:]-]{0,254})?[[:alnum:]])\.?/) %>'
  )

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
    'auth.ldap'  => { enabled => $use_ldap },
  }

  $ldap_group_mapping_defaults = [
    { group_dn => 'simp_grafana_admins',     org_role => 'Admin'  },
    { group_dn => 'simp_grafana_editors',    org_role => 'Editor' },
    { group_dn => 'simp_grafana_editors_ro', org_role => 'Read Only Editor' },
    { group_dn => 'simp_grafana_viewers',    org_role => 'Viewer' },
  ]

  $ldap_server_defaults = {
    host                  => $ldap_server,
    # XXX: If we don't use arithmetic here Puppet 3.x will convert
    # the Integer to a String when passing it to Ruby, and Grafana will
    # fail to start due to the invalid type.
    port                  => 635 + 1,
    use_ssl               => true,
    ssl_skip_verify       => true,
    bind_dn               => $bind_dn,
    bind_password         => $bind_pw,
    search_filter         => '(uid=%s)',
    search_base_dns       => ["ou=People,${base_dn}"],
    group_search_filter   => '(&(objectClass=posixGroup)(memberUid=%s))',
    group_search_base_dns => ["ou=Group,${base_dn}"],
    attributes            => {
      name      => 'givenName',
      surname   => 'sn',
      username  => 'uid',
      member_of => 'cn',
      email     => 'mail',
    },
    group_mappings => $ldap_group_mapping_defaults,
  }

  $ldap_cfg = {
    verbose_logging => true,
    servers         => [ $ldap_server_defaults ],
  }
}
