require 'spec_helper'

describe 'simp_grafana' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_grafana') }
    it { is_expected.to contain_class('simp_grafana') }
  end

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts.merge({
          :auditd_version => '2.4.3',
          :custom_hiera   => 'actual_spec_tests',
        })
      end

      context 'with minimal parameters' do
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('simp_grafana').with_trusted_nets(['127.0.0.1/8']) }
        it { is_expected.not_to contain_class('simp_grafana::config::firewall') }
        it { is_expected.not_to create_iptables__add_tcp_stateful_listen('allow_simp_grafana_tcp_connections').with_dports('8443') }
        it 'grants revoke_grafana_cap to grafana-server' do
          is_expected.to create_exec('revoke_grafana_caps').with(
            'command' => 'setcap -r /usr/sbin/grafana-server',
            'onlyif'  => 'getcap /usr/sbin/grafana-server | fgrep cap_net_bind_service+ep',
            'path'    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin']
          ).that_requires('Class[grafana::config]').that_notifies('Class[grafana::service]')
        end
        it { is_expected.not_to contain_class('simp_grafana::config::pki') }
        it { is_expected.not_to contain_pki__copy('grafana').with_source('/etc/pki/simp/x509') }
        it { is_expected.not_to contain_class('pki')}
        it { is_expected.not_to create_file('/etc/pki/simp_apps/grafana/x509')}
      end

      context 'when firewall management is enabled' do
        let(:params) {{
          :firewall => true
        }}
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('simp_grafana::config::firewall') }
        it { is_expected.to create_iptables__listen__tcp_stateful('allow_simp_grafana_tcp_connections').with_dports(8443) }
      end

      context 'when set to use a non-default port' do
        let(:params) {{
          :firewall => true,
          :cfg      => { 'server' => { 'http_port' => 3000 }},
        }}
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('simp_grafana::config::firewall') }
        it { is_expected.to create_iptables__listen__tcp_stateful('allow_simp_grafana_tcp_connections').with_dports(3000) }
        it 'revokes all Linux capabilities from grafana-server' do
          is_expected.to create_exec('revoke_grafana_caps').with(
            'command' => 'setcap -r /usr/sbin/grafana-server',
            'onlyif'  => 'getcap /usr/sbin/grafana-server | fgrep cap_net_bind_service+ep',
            'path'    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin']
          ).that_requires('Class[grafana::config]').that_notifies('Class[grafana::service]')
        end
      end

      context "when pki management is set to 'simp'" do
        let(:params) {{
          :pki => 'simp'
        }}
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('simp_grafana::config::pki') }
        it { is_expected.to contain_pki__copy('grafana').with_source('/etc/pki/simp/x509') }
        it { is_expected.to contain_class('pki')}
        it { is_expected.to create_file('/etc/pki/simp_apps/grafana/x509')}
      end

      context 'when PKI management is disabled' do
        let(:params) {{
          :pki => true
        }}
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('simp_grafana::config::pki') }
        it { is_expected.to contain_pki__copy('grafana') }
        it { is_expected.not_to contain_class('pki')}
        it { is_expected.to create_file('/etc/pki/simp_apps/grafana/x509')}
      end


      context 'when ldap is false' do
        let(:params) {{
          :ldap => false
        }}
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('grafana').with_ldap_cfg( {} ) }
      end


      context 'when ldap is true' do
        let(:params) {{
          :ldap => true
        }}
        let(:hieradata) { 'actual_spec_tests' }
        let(:data) {{
          'verbose_logging' => true,
          'servers'         => [
            {
              'port'                => 636,
              'use_ssl'             => true,
              'ssl_skip_verify'     => true,
              'search_filter'       => '(uid=%s)',
              'group_search_filter' => '(&(objectClass=posixGroup)(memberUid=%s))',
              'attributes' => {
                'name'      => 'givenName',
                'surname'   => 'sn',
                'username'  => 'uid',
                'member_of' => 'cn',
                'email'     => 'mail',
              },
              'group_mappings' => [
                { 'group_dn' => 'simp_grafana_admins',     'org_role' => 'Admin' },
                { 'group_dn' => 'simp_grafana_editors',    'org_role' => 'Editor' },
                { 'group_dn' => 'simp_grafana_editors_ro', 'org_role' => 'Read Only Editor' },
                { 'group_dn' => 'simp_grafana_viewers',    'org_role' => 'Viewer' }
              ],
              'host'                  => 'puppet',
              'bind_dn'               => 'uid=%s,DC=example,DC=com',
              'bind_password'         => '123$%^qweRTY',
              'search_base_dns'       => ['ou=People,DC=example,DC=com'],
              'group_search_base_dns' => ['ou=Group,DC=example,DC=com'],
            }
          ]
        }}
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('grafana').with_ldap_cfg(data) }
      end

      context 'with $ldap_cfg set' do
        let(:params) {{
          :ldap     => true,
          :ldap_cfg => {
            'verbose_logging' => true,
            'servers'         => [
              'bind_dn'               => 'uid=%s,DC=example,DC=com',
              'bind_password'         => '123$%^qweRTY',
              'group_search_base_dns' => ['ou=Group,DC=example,DC=com'],
              'group_search_filter'   => '(&(objectClass=posixGroup)(memberUid=%s))',
              'host'                  => 'puppet',
              'search_base_dns'       => ['ou=People,DC=example,DC=com'],
              'search_filter'       => '(uid=%s)',
              'attributes'    => {
                'name'      => 'givenName',
                'surname'   => 'sn',
                'username'  => 'uid',
                'member_of' => 'cn',
                'email'     => 'mail',
              }
            ]
          }
        }}
        let(:hieradata) { 'actual_spec_tests' }
        let(:data) {{
          'verbose_logging' => true,
          'servers'         => [
            {
              'bind_dn'               => 'uid=%s,DC=example,DC=com',
              'bind_password'         => '123$%^qweRTY',
              'group_search_base_dns' => ['ou=Group,DC=example,DC=com'],
              'group_search_filter' => '(&(objectClass=posixGroup)(memberUid=%s))',
              'host'                  => 'puppet',
              'search_base_dns'       => ['ou=People,DC=example,DC=com'],
              'search_filter'       => '(uid=%s)',
              'attributes'  => {
                'name'      => 'givenName',
                'surname'   => 'sn',
                'username'  => 'uid',
                'member_of' => 'cn',
                'email'     => 'mail',
              },
            }
          ]
        }}
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('grafana').with_ldap_cfg(data) }
      end

      context 'when $cfg is set' do
        let(:params) {{
          :cfg => { 'security' => { 'admin_password' => 'stubbed' } }
        }}
        let(:hieradata) { 'actual_spec_tests' }
        let(:data) {{
          'auth.ldap'       => { 'enabled' => false },
          'security'        => {
            'admin_password'   => 'stubbed',
            'disable_gravatar' => true
          },
          'server'          => {
            'cert_file' => '/etc/pki/simp_apps/grafana/x509/public/foo.example.com.pub',
            'cert_key'  => '/etc/pki/simp_apps/grafana/x509/private/foo.example.com.pem',
            'http_port' => 8443,
            'protocol'  => 'https'
          },
          'analytics'       => { 'reporting_enabled' => false },
          'auth.basic'      => { 'enabled' => false },
          'dashboards.json' => { 'enabled' => true },
          'snapshot'        => { 'external_enabled' => false },
          'users'           => {
            'allow_org_create' => true,
            'allow_sign_up'    => false,
            'auto_assign_org'  => true
          },
        }}
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('grafana').with_cfg(data) }
      end

    end
  end
end
