require 'spec_helper'

describe 'simp_grafana' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_grafana') }
    it { is_expected.to contain_class('simp_grafana') }
    it { is_expected.to contain_class('simp_grafana::params') }
  end

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts.merge({
          :auditd_version => '2.4.3',
          :custom_hiera => 'actual_spec_tests',
        })
      end

      context 'without any parameters' do
        let(:params) { {} }
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
        let(:params) { { :firewall => true } }
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('simp_grafana::config::firewall') }
        it { is_expected.to create_iptables__listen__tcp_stateful('allow_simp_grafana_tcp_connections').with_dports(8443) }
      end

      context 'when set to use a non-default port' do
        let(:params) {{
          :firewall => true,
          :cfg => { 'server' => { 'http_port' => 3000 } },
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
        let(:params) { { :pki => 'simp' } }
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('simp_grafana::config::pki') }
        it { is_expected.to contain_pki__copy('grafana').with_source('/etc/pki/simp/x509') }
        it { is_expected.to contain_class('pki')}
        it { is_expected.to create_file('/etc/pki/simp_apps/grafana/x509')}
      end

      context 'when PKI management is disabled' do
        let(:params) { { :pki => true } }
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('simp_grafana::config::pki') }
        it { is_expected.to contain_pki__copy('grafana') }
        it { is_expected.not_to contain_class('pki')}
        it { is_expected.to create_file('/etc/pki/simp_apps/grafana/x509')}
      end


      context 'when ldap is false' do
        let(:params) { {:ldap => false} }
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('grafana').with_ldap_cfg( {} ) }
      end


      context 'when ldap is true' do
        let(:params) { {:ldap => true} }
        it 'is expected to contain class grafana with ldap_cfg'
      end

    end
  end

  context 'on an unsupported operating system' do
    describe 'without any parameters on Solaris/Nexenta' do
      let(:facts) do
        {
          :osfamily        => 'Solaris',
          :operatingsystem => 'Nexenta',
        }
      end

      it { expect { is_expected.to contain_package('simp_grafana') }.to raise_error(Puppet::Error, /Nexenta not supported/) }
    end
  end
end
