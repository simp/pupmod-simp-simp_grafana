# == Class simp_grafana::params
#
# This class is meant to be called from simp_grafana.
# It sets variables according to platform.
#
class simp_grafana::params {

  $client_nets        = defined('$::client_nets') ? { true => $::client_nets, default => hiera('client_nets', ['127.0.0.1/32']) }
  $enable_auditing    = defined('$::enable_auditing') ? { true => $::enable_auditing, default => hiera('enable_auditing', false) }
  $enable_firewall    = defined('$::enable_firewall') ? { true => $::enable_firewall, default => hiera('enable_firewall', false) }
  $enable_logging     = defined('$::enable_logging') ? { true => $::enable_logging, default => hiera('enable_logging', false) }
  $enable_pki         = defined('$::enable_pki') ? { true => $::enable_pki, default => hiera('enable_pki', false) }
  $enable_selinux     = defined('$::enable_selinux') ? { true => $::enable_selinux, default => hiera('enable_selinux', false) }
  $enable_tcpwrappers = defined('$::enable_tcpwrappers') ? { true => $::enable_tcpwrappers, default => hiera('enable_tcpwrappers', false) }

  case $::osfamily {
    'RedHat': {
      $package_name = 'simp_grafana'
      $service_name = 'simp_grafana'
    }
    default: {
      fail("${::operatingsystem} not supported")
    }
  }
}
