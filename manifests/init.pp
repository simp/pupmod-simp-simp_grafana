# == Class: simp_grafana
#
# Full description of SIMP module 'simp_grafana' here.
#
# === Welcome to SIMP!
# This module is a component of the System Integrity Management Platform, a
# a managed security compliance framework built on Puppet.
#
# ---
# *FIXME:* verify that the following paragraph fits this module's characteristics!
# ---
#
# This module is optimally designed for use within a larger SIMP ecosystem, but
# it can be used independently:
#
# * When included within the SIMP ecosystem,
#   security compliance settings will be managed from the Puppet server.
#
# * If used independently, all SIMP-managed security subsystems are disabled by
#   default, and must be explicitly opted into by administrators.  Please review
#   the +client_nets+ and +$enable_*+ parameters for details.
#
#
# == Parameters
#
# [*service_name*]
#   The name of the simp_grafana service.
#   Type: String
#   Default:  +$::simp_grafana::params::service_name+
#
# [*package_name*]
#   Type: String
#   Default:  +$::simp_grafana::params::package_name+
#   The name of the simp_grafana package.
#
# [*client_nets*]
#   Type: Array of Strings
#   Default: +['127.0.0.1/32']+
#   A whitelist of subnets (in CIDR notation) permitted access.
#
# [*enable_auditing*]
#   Type: Boolean
#   Default: +false+
#   If true, manage auditing for simp_grafana.
#
# [*enable_firewall*]
#   Type: Boolean
#   Default: +false+
#   If true, manage firewall rules to acommodate simp_grafana.
#
# [*enable_logging*]
#   Type: Boolean
#   Default: +false+
#   If true, manage logging configuration for simp_grafana.
#
# [*enable_pki*]
#   Type: Boolean
#   Default: +false+
#   If true, manage PKI/PKE configuration for simp_grafana.
#
# [*enable_selinux*]
#   Type: Boolean
#   Default: +false+
#   If true, manage selinux to permit simp_grafana.
#
# [*enable_tcpwrappers*]
#   Type: Boolean
#   Default: +false+
#   If true, manage TCP wrappers configuration for simp_grafana.
#
# == Authors
#
# * simp
#
class simp_grafana (
  $service_name       = $::simp_grafana::params::service_name,
  $package_name       = $::simp_grafana::params::package_name,
  $tcp_listen_port    = '443',
  $client_nets        = $::simp_grafana::params::client_nets,
  $enable_auditing    = $::simp_grafana::params::enable_auditing,
  $enable_firewall    = $::simp_grafana::params::enable_firewall,
  $enable_logging     = $::simp_grafana::params::enable_logging,
  $enable_pki         = $::simp_grafana::params::enable_pki,
  $enable_selinux     = $::simp_grafana::params::enable_selinux,
  $enable_tcpwrappers = $::simp_grafana::params::enable_tcpwrappers,
) inherits ::simp_grafana::params {

  validate_string($service_name)
  validate_string($package_name)
  validate_string($tcp_listen_port)
  validate_array($client_nets)
  validate_bool($enable_auditing)
  validate_bool($enable_firewall)
  validate_bool($enable_logging)
  validate_bool($enable_pki)
  validate_bool($enable_selinux)
  validate_bool($enable_tcpwrappers)

  require '::grafana'
  #include '::grafana'
  #Class['::grafana'] -> Class['::simp_grafana']

  if $enable_auditing {
    include '::simp_grafana::config::auditing'
  }

  if $enable_firewall {
    include '::simp_grafana::config::firewall'
  }

  if $enable_logging {
    include '::simp_grafana::config::logging'
  }

  if $enable_pki {
    include '::simp_grafana::config::pki'
  }

  if $enable_selinux {
    include '::simp_grafana::config::selinux'
  }

  if $enable_tcpwrappers {
    include '::simp_grafana::config::tcpwrappers'
  }
}
