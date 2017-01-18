# SIMP server site.pp
hiera_include('classes')

#::pam::access::rule { "Allow 'vagrant'":
#  users   => 'vagrant',
#  origins => ['ALL'],
#}

::tcpwrappers::allow { 'sshd':
  pattern => 'ALL',
}

::iptables::listen::tcp_stateful { 'allow_ssh':
  trusted_nets => ['10.255.0.0/16', '10.0.2.0/24'],
  dports       => [22],
}

package { 'openldap-clients': ensure => latest }
