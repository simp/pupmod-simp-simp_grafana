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
        facts.merge(:auditd_version => '2.4.3')
      end

      context 'without any parameters' do
        let(:params) { {} }
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('simp_grafana').with_client_nets(['127.0.0.0/8']) }
        it { is_expected.to contain_class('simp_grafana::config::firewall') }
        it { is_expected.to create_iptables__add_tcp_stateful_listen('allow_simp_grafana_tcp_connections').with_dports('443') }
        it 'grants CAP_NET_BIND_SERVICE to grafana-server' do
          is_expected.to create_exec('grant_grafana_cap_net_bind_service').with(
            'command' => 'setcap cap_net_bind_service=+ep /usr/sbin/grafana-server',
            'unless'  => 'getcap /usr/sbin/grafana-server | fgrep cap_net_bind_service+ep',
            'path'    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin']
          ).that_requires('Class[grafana::config]').that_notifies('Class[grafana::service]')
        end
        it { is_expected.to contain_class('simp_grafana::config::pki') }
        it { is_expected.to contain_pki__copy('/etc/grafana') }
      end

      context 'when firewall management is disabled' do
        let(:params) { { :enable_firewall => false } }
        it_behaves_like 'a structured module'
        it { is_expected.not_to contain_class('simp_grafana::config::firewall') }
        it { is_expected.not_to create_iptables__add_tcp_stateful_listen('allow_simp_grafana_tcp_connections').with_dports('443') }
      end

      context 'when set to use a non-default port' do
        let(:params) do
          {
            :cfg => { 'server' => { 'http_port' => 3000 } },
          }
        end
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('simp_grafana::config::firewall') }
        it { is_expected.to create_iptables__add_tcp_stateful_listen('allow_simp_grafana_tcp_connections').with_dports('3000') }
        it 'revokes all Linux capabilities from grafana-server' do
          is_expected.to create_exec('revoke_grafana_caps').with(
            'command' => 'setcap -r /usr/sbin/grafana-server',
            'onlyif'  => 'getcap /usr/sbin/grafana-server | fgrep cap_net_bind_service+ep',
            'path'    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin']
          ).that_requires('Class[grafana::config]').that_notifies('Class[grafana::service]')
        end
      end

      context 'when PKI managemnt is disabled' do
        let(:params) { { :enable_pki => false } }
        it_behaves_like 'a structured module'
        it { is_expected.not_to contain_class('simp_grafana::config::pki') }
        it { is_expected.not_to contain_pki__copy('/etc/grafana') }
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
