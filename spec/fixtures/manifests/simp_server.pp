# SIMP server site.pp
hiera_include('classes')

#::pam::access::manage { "Allow 'vagrant'":
#  users   => 'vagrant',
#  origins => ['ALL'],
#}

::tcpwrappers::allow{ 'sshd':
  pattern => 'ALL',
}

::iptables::add_tcp_stateful_listen { 'allow_ssh':
  client_nets => ['10.255.0.0/16', '10.0.2.0/24'],
  dports      => ['22'],
}

package { 'openldap-clients': ensure => latest }
