## Class: simp_grafana
#
# This module acts as a SIMP wrapper ("profile") for the Puppet, Inc. Approved
# Grafana module written by Bill Fraser and maintained by Vox Pupuli.  It sets
# baseline of secure defaults and integrates Grafana with other SIMP components.
#
# @note If SIMP integration is not required, direct use of the component Grafana
#   module is advised.
#
### Welcome to SIMP!
#
# This module is a component of the System Integrity Management Platform (SIMP),
# a managed security compliance framework built on Puppet.
#
# This module is optimally designed for use within a larger SIMP ecosystem, but
# it can be used independently:
#
# * As a SIMP wrapper module, the defaults use the larger SIMP ecosystem to
#   manage security compliance settings from the Puppet server.
#
# * If used independently, all SIMP-managed security subsystems may be disabled
#   via the `firewall` and `pki` settings.
#
## Parameters
#
# @param trusted_nets A whitelist of subnets
#   (in CIDR notation) permitted access.
#
# @param firewall If true, manage firewall rules to
#   accommodate simp_grafana.
#
# @param pki
#   * If 'simp', include SIMP's pki module and use pki::copy to manage
#     application certs in /etc/pki/simp_apps/grafana/x509
#   * If true, do *not* include SIMP's pki module, but still use pki::copy
#     to manage certs in /etc/pki/simp_apps/grafana/x509
#   * If false, do not include SIMP's pki module and do not use pki::copy
#     to manage certs.  You will need to appropriately assign a subset of:
#     * app_pki_dir
#     * app_pki_key
#     * app_pki_cert
#     * app_pki_ca
#     * app_pki_ca_dir
#
# @param app_pki_external_source
#   * If pki = 'simp' or true, this is the directory from which certs will be
#     copied, via pki::copy.  Defaults to /etc/pki/simp/x509.
#
#   * If pki = false, this variable has no effect.
#
# @param app_pki_dir
#   NOTE: Controlled in params.pp
#   This variable controls the basepath of $app_pki_key, $app_pki_cert,
#   $app_pki_ca, $app_pki_ca_dir, and $app_pki_crl.
#   It defaults to /etc/pki/simp_apps/grafana/x509.
#
# @param app_pki_key
#   NOTE: Controlled in params.pp
#   Path and name of the private SSL key file
#
# @param app_pki_cert
#   NOTE: Controlled in params.pp
#   Path and name of the public SSL certificate
#
# @param cfg A passthrough to the Grafana component module, this will be
#   merged with the SIMP defaults in `::simp_grafana::params`.
#
# @param ldap_cfg A passthrough to the Grafana component module.
#   merged with the SIMP defaults in `::simp_grafana::params`.
#   @note If using Puppet 3.x, Integer values in this Hash must be declared with
#     arithmetic expression to avoid converison to a String.  For example, to
#     set a value to `1`, the value should be declared as `0 + 1`.
#
# @param install_method A passthrough to the Grafana module, this sets
#   the installation method of Grafana to a repository by default since this is
#   the SIMP preferred method for installing packages.
#
# @param use_internet_repo If set, allow the ::grafana module to point
#   to the appropriate package repository on the Internet automatically.
#
# @param version Version of grafana to install
#
# @param rpm_iteration
#
# @param simp_dashboards Install SIMP dashboards
#
## Examples
#
# @example Resource-style class declaration
#   class { 'simp_grafana':
#     firewall => true,
#     pki      => true,
#     trusted_nets     => ['10.255.0.0/16'],
#     cfg             => { 'auth.ldap' => { enabled => true } },
#     ldap_cfg        => {
#       verbose_logging => true,
#       servers         => [
#         {
#           host                  => 'ldap.example.com',
#           # @note: If using Puppet 3.x, the param `port` MUST use arithmetic.
#           #   If it does not, it will be converted into a string and the LDAP
#           #   configuration file will fail to load with a type error.
#           port                  => 635 + 1,
#           use_ssl               => true,
#           bind_dn               => 'uid=grafana,ou=Services,dc=test',
#           bind_password         => '123$%^qweRTY',
#           search_filter         => '(uid=%s)',
#           search_base_dns       => ['ou=People,dc=test'],
#           group_search_filter   => '(&(objectClass=posixGroup)(memberUid=%s))',
#           group_search_base_dns => ['ou=Group,dc=test'],
#           attributes            => {
#             name      => 'givenName',
#             surname   => 'sn',
#             username  => 'uid',
#             member_of => 'gidNumber',
#             email     => 'mail',
#           },
#           group_mappings => [
#             { group_dn => '50000', org_role => 'Admin'  },
#             { group_dn => '50001', org_role => 'Editor' },
#           ],
#         },
#       ],
#     },
#   }
#
# @author Lucas Yamanishi <lucas.yamanishi@onyxpoint.com>
#
class simp_grafana (
  Simplib::Netlist              $trusted_nets            = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1/8'] }),
  Boolean                       $firewall                = simplib::lookup('simp_options::firewall', { 'default_value' => false }),
  Boolean                       $ldap                    = simplib::lookup('simp_options::ldap', { 'default_value' => false }),
  Variant[Boolean,Enum['simp']] $pki                     = simplib::lookup('simp_options::pki', { 'default_value' => false }),
  String                        $app_pki_external_source = simplib::lookup('simp_options::pki::source', { 'default_value' => '/etc/pki/simp/x509' }),
  Hash                          $cfg                     = {},
  Hash                          $ldap_cfg                = {},
  String                        $install_method          = 'repo',
  Boolean                       $use_internet_repo       = false,
  String                        $version                 = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  String                        $rpm_iteration           = '1',
  Boolean                       $simp_dashboards         = false,
  String                        $admin_pw                = passgen('grafana'),
  String                        $app_pki_dir             = '/etc/pki/simp_apps/grafana/x509',
  String                        $app_pki_key             = "${app_pki_dir}/private/${facts['fqdn']}.pem",
  String                        $app_pki_cert            = "${app_pki_dir}/public/${facts['fqdn']}.pub",
 ) {

  #assert_metadata_os()

  # Static defaults
  $_cfg = {
    server       => {
      # http_port => 8443,
      # protocol  => 'https',
      cert_file => $app_pki_cert,
      cert_key  => $app_pki_key,
    },
    security     => {
      admin_password   => $admin_pw,
      # disable_gravatar => true,
    },
    # users        => {
    #   allow_sign_up    => false,
    #   allow_org_create => true,
    #   auto_assign_org  => true,
    # },
    # 'auth.basic' => { enabled => false },
    'auth.ldap'  => { enabled => $ldap },
    #Allows SIMP dashboards to be read from the file system
    # 'dashboards.json' => { enabled => true },
    # analytics   => { reporting_enabled => false },
    # snapshot    => { external_enabled => false },
  }

  if ($ldap) {

    $ldap_group_mapping_defaults = [
      { group_dn => 'simp_grafana_admins',     org_role => 'Admin'  },
      { group_dn => 'simp_grafana_editors',    org_role => 'Editor' },
      { group_dn => 'simp_grafana_editors_ro', org_role => 'Read Only Editor' },
      { group_dn => 'simp_grafana_viewers',    org_role => 'Viewer' },
    ]

    $base_dn = simplib::lookup('simp_options::ldap::base_dn', { 'default_value' => simplib::ldap::domain_to_dn("example.com") } )
    $bind_dn = simplib::lookup('simp_options::ldap::bind_dn', { 'default_value' => "uid=%s,${base_dn}" } )
    $bind_pw = simplib::lookup('simp_options::ldap::bind_pw', { 'default_value' => undef } )

    $ldap_urls   = simplib::lookup('simp_options::ldap::uri', { 'default_value' => [''] } )
    $ldap_url    = $ldap_urls[-1]
    $ldap_server = inline_template(
      '<%= @ldap_url.match(/(([[:alnum:]][[:alnum:]-]{0,254})?[[:alnum:]]\.)+(([[:alnum:]][[:alnum:]-]{0,254})?[[:alnum:]])\.?/) %>'
      )
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

    $_ldap_cfg = {
      verbose_logging => true,
      servers         => [ $ldap_server_defaults ],
    }
  }
  else {
    $_ldap_cfg = {}
  }

  $merged_cfg = deep_merge($_cfg, $cfg)
  $merged_ldap_cfg = deep_merge($_ldap_cfg, $ldap_cfg)

  if $merged_cfg['auth.ldap']['enabled'] { include '::simp_openldap::client' }

  if $merged_cfg['server']['http_port'] <= 1024 {
    exec { 'grant_grafana_cap_net_bind_service':
      command => 'setcap cap_net_bind_service=+ep /usr/sbin/grafana-server',
      unless  => 'getcap /usr/sbin/grafana-server | fgrep cap_net_bind_service+ep',
      path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
      require => Class['::grafana::config'],
      notify  => Class['::grafana::service'],
    }
  } else {
    exec { 'revoke_grafana_caps':
      command => 'setcap -r /usr/sbin/grafana-server',
      onlyif  => 'getcap /usr/sbin/grafana-server | fgrep cap_net_bind_service+ep',
      path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
      require => Class['::grafana::config'],
      notify  => Class['::grafana::service'],
    }
  }

  if $firewall {
    include '::simp_grafana::config::firewall'
  }

  if $pki {
    include '::simp_grafana::config::pki'
    Class['grafana'] -> Class['simp_grafana::config::pki']
  }

  class { '::grafana':
    cfg                 => $merged_cfg,
    ldap_cfg            => $merged_ldap_cfg,
    install_method      => $install_method,
    manage_package_repo => $use_internet_repo,
    version             => $version,
    rpm_iteration       => $rpm_iteration
  }

  if $simp_dashboards {
    package { 'simp-grafana-dashboards':
      ensure => 'latest',
    }
  }
}
