## Class: simp_grafana::config::config::pki
#
# This class is meant to be called from simp_grafana.
# It ensures that pki rules are defined.
#
# @private
#
class simp_grafana::config::pki {
  assert_private()

  include '::pki'

  ::pki::copy { '/etc/grafana': group => 'grafana' }
}

