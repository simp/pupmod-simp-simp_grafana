# This module acts as a SIMP wrapper ("profile") for the Puppet, Inc. Approved
# Grafana module written by Bill Fraser and maintained by Vox Pupuli.  It sets
# baseline of secure defaults and integrates Grafana with other SIMP components.
#
# @note If SIMP integration is not required, direct use of the component Grafana
#   module is advised.
#
# @note If providing LDAP configuration via $ldap_cfg, SIMP's smart defaults
#   will not be used. The defaults will also not be used if $ldap or
#  `simp_options::ldap` is false. Make sure all needed options are set if
#  specifying a custom $ldap_cfg.
#
# # Welcome to SIMP!
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
# @param trusted_nets A whitelist of subnets
#   (in CIDR notation) permitted access.
#
# @param firewall If true, manage firewall rules to
#   accommodate simp_grafana.
#
# @param ldap If true, enable ldap authentication using $ldap_cfg
#   The following settings are set in puppet and are parameters of this class:
#   * $ldap_urls
#   * $base_dn
#   * $bind_dn
#   * $bind_pw
#
# @param ldap_urls LDAP server urls
#
# @param base_dn Base DN of the LDAP server
#
# @param bind_dn Bind DN of the LDAP server
#
# @param bind_pw Bind passworf for the bind_dn
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
#   This variable controls the basepath of $app_pki_key, $app_pki_cert,
#   $app_pki_ca, $app_pki_ca_dir, and $app_pki_crl.
#
# @param app_pki_key Path and name of the private SSL key file
#
# @param app_pki_cert Path and name of the public SSL certificate
#
# @param default_cfg Default values for grafana
#
# @param cfg A passthrough to the Grafana component module, this will be
#   merged with the SIMP defaults in `default_cfg`.
#
# @param ldap_cfg Grafana ldap configuration. If this is set, make sure to
#   set all the params needed. There will be no merging.
#
#   @see http://docs.grafana.org/installation/ldap/
#
# @param simp_ldap_conf Defaults for the SIMP LDAP server, using data in
#   modules. These settings can be checked by running
#   `puppet lookup simp_grafana::simp_ldap_conf`.
#
# @param ldap_verbose_logging Enables verbose logging for the LDAP connections
#
# @param admin_pw Grafana's default admin password
#
# @param install_method A passthrough to the Grafana module, this sets
#   the installation method of Grafana to a repository by default since this is
#   the SIMP preferred method for installing packages.
#
# @param use_internet_repo If set, allow the `grafana` module to point
#   to the appropriate package repository on the Internet automatically.
#
# @param version Version of grafana to install
#
# @param rpm_iteration Passed directly to the `grafana` class
#
# @param simp_dashboards Install SIMP dashboards
#
# @example Resource-style class declaration
#   class { 'simp_grafana':
#     firewall        => true,
#     pki             => true,
#     trusted_nets    => ['10.255.0.0/16'],
#     cfg             => { 'auth.ldap' => { enabled => true } },
#     ldap_cfg        => {
#       verbose_logging => true,
#       servers         => [
#         {
#           host                  => 'ldap.example.com',
#           port                  => 636,
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
#             { group_dn => 'admin', org_role => 'Admin'  },
#             { group_dn => '50001', org_role => 'Editor' },
#           ],
#         },
#       ],
#     },
#   }
#
# @author https://github.com/simp/pupmod-simp-simp_grafana/graphs/contributors
#
class simp_grafana (
  Hash                          $default_cfg,
  Hash                          $cfg,
  Hash                          $ldap_cfg,
  String                        $install_method,
  Boolean                       $use_internet_repo,
  String                        $rpm_iteration,
  Boolean                       $simp_dashboards,
  String                        $app_pki_dir,
  Hash                          $simp_ldap_conf,
  Boolean                       $ldap_verbose_logging,
  String                        $admin_pw                = simplib::passgen('simp_grafana'),
  Simplib::Netlist              $trusted_nets            = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1/8'] }),
  Boolean                       $firewall                = simplib::lookup('simp_options::firewall', { 'default_value' => false }),
  Boolean                       $ldap                    = simplib::lookup('simp_options::ldap', { 'default_value' => false }),
  String                        $version                 = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  Variant[Boolean,Enum['simp']] $pki                     = simplib::lookup('simp_options::pki', { 'default_value' => false }),
  String                        $app_pki_external_source = simplib::lookup('simp_options::pki::source', { 'default_value' => '/etc/pki/simp/x509' }),
  String                        $app_pki_key             = "${app_pki_dir}/private/${facts['fqdn']}.pem",
  String                        $app_pki_cert            = "${app_pki_dir}/public/${facts['fqdn']}.pub",
  String                        $base_dn                 = simplib::lookup('simp_options::ldap::base_dn', { 'default_value' => simplib::ldap::domain_to_dn("example.com") } ),
  String                        $bind_dn                 = simplib::lookup('simp_options::ldap::bind_dn', { 'default_value' => "uid=%s,${base_dn}" } ),
  String                        $bind_pw                 = simplib::lookup('simp_options::ldap::bind_pw', { 'default_value' => undef } ),
  Array[Simplib::URI,1]         $ldap_urls               = simplib::lookup('simp_options::ldap::uri', { 'default_value' => undef } )
) {

  $_simp_ldap_server_name = split($ldap_urls[0], 'ldap://')[1]
  $_simp_ldap_server = $simp_ldap_conf + {
    # add options that override or are not avilable in hiera
    'bind_dn'               => $bind_dn,
    'bind_password'         => $bind_pw,
    'group_search_base_dns' => ["ou=Group,${base_dn}"],
    'host'                  => $_simp_ldap_server_name,
    'search_base_dns'       => ["ou=People,${base_dn}"],
  }

  $_cfg = deep_merge({
    # add options that override or are not avilable in hiera
    'auth.ldap' => { 'enabled'        => $ldap },
    'security'  => { 'admin_password' => $admin_pw },
    'server'    => {
      'cert_file' => $app_pki_cert,
      'cert_key'  => $app_pki_key,
    },
  }, $default_cfg)

  # Only use SIMP's ldap server conf if the catalyst is true, and
  # there isn't any specified ldap configuration
  if empty($ldap_cfg) and ($ldap or ($cfg['auth.ldap'] == { 'enabled' => true })) {
    $_ldap_cfg = {
      'verbose_logging' => $ldap_verbose_logging,
      'servers'         => [$_simp_ldap_server]
    }
  }
  else {
    $_ldap_cfg = {}
  }

  $merged_cfg      = deep_merge($_cfg, $cfg)
  $merged_ldap_cfg = deep_merge($_ldap_cfg, $ldap_cfg)

  if $merged_cfg['auth.ldap']['enabled'] == true { include 'simp_openldap::client' }

  if $merged_cfg['server']['http_port'] <= 1024 {
    exec { 'grant_grafana_cap_net_bind_service':
      command => 'setcap cap_net_bind_service=+ep /usr/sbin/grafana-server',
      unless  => 'getcap /usr/sbin/grafana-server | fgrep cap_net_bind_service+ep',
      path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
      require => Class['grafana::config'],
      notify  => Class['grafana::service'],
    }
  }
  else {
    exec { 'revoke_grafana_caps':
      command => 'setcap -r /usr/sbin/grafana-server',
      onlyif  => 'getcap /usr/sbin/grafana-server | fgrep cap_net_bind_service+ep',
      path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
      require => Class['grafana::config'],
      notify  => Class['grafana::service'],
    }
  }

  if $firewall {
    include 'simp_grafana::config::firewall'
  }

  if $pki {
    include 'simp_grafana::config::pki'
    Class['simp_grafana::config::pki'] ~> Class['grafana::service']
  }

  class { 'grafana':
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
