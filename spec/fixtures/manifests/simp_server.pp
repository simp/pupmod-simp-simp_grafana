# SIMP server site.pp
lookup('classes', Array[String], 'unique').include

#::pam::access::rule { "Allow 'vagrant'":
#  users   => 'vagrant',
#  origins => ['ALL'],
#}

tcpwrappers::allow { 'sshd':
  pattern => 'ALL',
}

package { 'openldap-clients': ensure => latest }
