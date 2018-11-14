include 'simp_elasticsearch'
include 'tcpwrappers'
include 'iptables'

# pki::copy { '/etc/httpd/conf':
#   source => '/etc/pki/simp-testing/pki',
#   before => Class['simp_elasticsearch'],
# }

tcpwrappers::allow { 'sshd':
  pattern => 'ALL',
}
