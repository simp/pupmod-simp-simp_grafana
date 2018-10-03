## Class simp_grafana::config::firewall
#
# This class is meant to be called from simp_grafana.
# It ensures that firewall rules are defined.
#
# @private
#
class simp_grafana::config::firewall {
  assert_private()

  include 'iptables'

  iptables::listen::tcp_stateful { 'allow_simp_grafana_tcp_connections':
    trusted_nets => $::simp_grafana::trusted_nets,
    dports       => $::simp_grafana::merged_cfg['server']['http_port'],
  }

}
