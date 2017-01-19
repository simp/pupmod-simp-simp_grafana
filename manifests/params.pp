## Class: simp_grafana::params
#
# This class is meant to be called from simp_grafana.
# It sets variables according to platform.
#
# @private
#
class simp_grafana::params {

  $trusted_nets = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.0/8'] })
  $firewall     = simplib::lookup('simp_options::firewall', { 'default_value' => false })
  $ldap         = simplib::lookup('simp_options::ldap', { 'default_value' => false })

  $admin_pw = passgen('grafana')

  $app_pki_dir             = '/etc/pki/simp_apps/grafana/x509'
  $app_pki_key             = "${app_pki_dir}/private/${facts['fqdn']}.pem"
  $app_pki_cert            = "${app_pki_dir}/public/${facts['fqdn']}.pub"

  $base_dn = simplib::lookup('simp_options::ldap::base_dn', { 'default_value' => 'dc=invalid' } )
  $bind_dn = simplib::lookup('simp_options::ldap::bind_dn', { 'default_value' => "uid=%s,${base_dn}" } )
  $bind_pw = simplib::lookup('simp_options::ldap::bind_pw', { 'default_value' => undef } )

  $ldap_urls   = hiera_array('simp_options::ldap::uri', [''])
  $ldap_url    = $ldap_urls[0]
  $ldap_server = inline_template(
    '<%= @ldap_url.match(/(([[:alnum:]][[:alnum:]-]{0,254})?[[:alnum:]]\.)+(([[:alnum:]][[:alnum:]-]{0,254})?[[:alnum:]])\.?/) %>'
  )

  case $facts['osfamily'] {
    'RedHat': { }
    default: {
      fail("${::operatingsystem} not supported")
    }
  }

  # Static defaults
  $cfg = {
    server       => {
      http_port => 8443,
      protocol  => 'https',
      cert_file => $app_pki_cert,
      cert_key  => $app_pki_key,
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
    'auth.ldap'  => { enabled => $ldap },
    #Allows SIMP dashboards to be read from the file system
    'dashboards.json' => { enabled => true },
  }

  $ldap_group_mapping_defaults = [
    { group_dn => 'simp_grafana_admins',     org_role => 'Admin'  },
    { group_dn => 'simp_grafana_editors',    org_role => 'Editor' },
    { group_dn => 'simp_grafana_editors_ro', org_role => 'Read Only Editor' },
    { group_dn => 'simp_grafana_viewers',    org_role => 'Viewer' },
  ]

  $ldap_server_defaults = {
    host                  => $ldap_server,
    port                  => 636,
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
