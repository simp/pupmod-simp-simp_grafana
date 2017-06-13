## Class: simp_grafana::params
#
# This class is meant to be called from simp_grafana.
# It sets variables according to platform.
#
# @private
#
class simp_grafana::params {

  case $facts['osfamily'] {
    'RedHat': { }
    default: {
      fail("${::operatingsystem} not supported")
    }
  }
}
