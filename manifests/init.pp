## Class: simp_grafana
#
# This module acts as a SIMP wrapper ("profile") for the Puppet, Inc. Approved
# Grafana module written and maintained by Bill Fraser.  It sets a basline of
# secure defaults and integrates Grafan with other SIMP components.
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
#   acommodate simp_grafana.
#
# @param pki If true, manage PKI/PKE configuration for
#   `simp_grafana`.
#
# @param cfg A passthrough to the Grafana component module, this will be
#   merged with the SIMP defaults in `::simp_grafana::params`.
#
# @param ldap_cfg A passthrough to the Grafana component module.
#   Unlike the `cfg` param, this does not currently merge with any defaults, but
#   is provided as a convinence.
#   @note If using Puppet 3.x, Integer values in this Hash must be declared with
#     arithmetic expression to avoid converison to a String.  For example, to
#     set a value to `1`, the value should be declared as `0 + 1`.
#
# @param install_method A passthrough to the Grafana module, this sets
#   the installation method of Grafana to a repository by default since this is
#   the SIMP preferred method for installing packages.
#
# @param use_intenet_repo If set, allow the ::grafana module to point
#   to the appropriate package repository on the Internet automatically.
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
  Simplib::Netlist              $trusted_nets      = $::simp_grafana::params::trusted_nets,
  Boolean                       $firewall          = $::simp_grafana::params::firewall,
  Variant[Boolean,Enum['simp']] $pki               = $::simp_grafana::params::pki,
  Hash                          $cfg               = {},
  Hash                          $ldap_cfg          = {},
  String                        $install_method    = 'repo',
  Boolean                       $use_internet_repo = false,
  # Need to set the version numbers until the upstream module can support "latest"
  String                        $version           = '3.1.1',
  String                        $rpm_iteration     = '1470047149',
  Boolean                       $simp_dashboards   = false
) inherits ::simp_grafana::params {

  $merged_cfg = deep_merge($::simp_grafana::params::cfg, $cfg)
  $merged_ldap_cfg = deep_merge($::simp_grafana::params::ldap_cfg, $ldap_cfg)

  if $merged_cfg['auth.ldap']['enabled'] { include '::openldap::client' }

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
