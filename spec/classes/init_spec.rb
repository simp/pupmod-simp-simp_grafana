require 'spec_helper'

describe 'simp_grafana' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_grafana') }
    it { is_expected.to contain_class('simp_grafana') }
    it { is_expected.to contain_class('simp_grafana::params') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        context 'simp_grafana class without any parameters' do
          let(:params) { {} }
          it_behaves_like 'a structured module'
          it { is_expected.to contain_class('simp_grafana').with_client_nets(['127.0.0.1/32']) }
        end

        context 'simp_grafana class with firewall enabled' do
          let(:params) do
            {
              :client_nets => ['10.0.2.0/24'],
              :tcp_listen_port => '1234',
              :enable_firewall => true,
            }
          end
          # ##it_behaves_like "a structured module"
          it { is_expected.to contain_class('simp_grafana::config::firewall') }

          it { is_expected.to create_iptables__add_tcp_stateful_listen('allow_simp_grafana_tcp_connections').with_dports('1234') }
        end

        context 'simp_grafana class with selinux enabled' do
          let(:params) do
            {
              :enable_selinux => true,
            }
          end
          # ##it_behaves_like "a structured module"
          it { is_expected.to contain_class('simp_grafana::config::selinux') }
          it { is_expected.to create_notify('FIXME: selinux') }
        end

        context 'simp_grafana class with auditing enabled' do
          let(:params) do
            {
              :enable_auditing => true,
            }
          end
          # ##it_behaves_like "a structured module"
          it { is_expected.to contain_class('simp_grafana::config::auditing') }
          it { is_expected.to create_notify('FIXME: auditing') }
        end

        context 'simp_grafana class with logging enabled' do
          let(:params) do
            {
              :enable_logging => true,
            }
          end
          # ##it_behaves_like "a structured module"
          it { is_expected.to contain_class('simp_grafana::config::logging') }
          it { is_expected.to create_notify('FIXME: logging') }
        end
      end
    end
  end

  context 'unsupported operating system' do
    describe 'simp_grafana class without any parameters on Solaris/Nexenta' do
      let(:facts) do
        {
          :osfamily => 'Solaris',
          :operatingsystem => 'Nexenta',
        }
      end

      it { expect { is_expected.to contain_package('simp_grafana') }.to raise_error(Puppet::Error, /Nexenta not supported/) }
    end
  end
end
