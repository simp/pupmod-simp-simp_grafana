## Class: simp_grafana::config::config::pki
#
# This class is meant to be called from simp_grafana.
# It ensures that pki rules are defined.
#
# @private
#
class simp_grafana::config::pki (
  Variant[Enum['simp'],Boolean] $pki = $::simp_grafana::pki,
) {
  assert_private()

  ::pki::copy { 'grafana':
    pki   => $pki,
    group => 'grafana',
  }
}
