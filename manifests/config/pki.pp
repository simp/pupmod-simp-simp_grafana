## Class: simp_grafana::config::config::pki
#
# This class is meant to be called from simp_grafana.
# It ensures that pki rules are defined.
#
# @private
#
class simp_grafana::config::pki (
  Variant[Enum['simp'],Boolean] $pki                     = $::simp_grafana::pki,
  Stdlib::Absolutepath          $app_pki_external_source = $::simp_grafana::app_pki_external_source
) {
  assert_private()

  ::pki::copy { 'grafana':
    pki    => $pki,
    source => $app_pki_external_source,
    group  => 'grafana',
  }
}

