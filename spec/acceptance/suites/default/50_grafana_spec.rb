require 'spec_helper_acceptance'
require 'json'

test_name 'simp_grafana'

simp_server          = only_host_with_role(hosts, 'simp_server')
simp_fqdn            = fact_on(simp_server, 'fqdn')
elasticsearch_server = only_host_with_role(hosts, 'elasticsearch_server')
elasticsearch_fqdn   = fact_on(elasticsearch_server, 'fqdn')
grafana              = only_host_with_role(hosts, 'grafana')
grafana_fqdn         = fact_on(grafana, 'fqdn')
grafana_port         = "8443"

default_hieradata = ERB.new(File.read(File.join(FIXTURE_DIR, 'hieradata', 'default.yaml.erb'))).result(binding)
grafana_hieradata = ERB.new(File.read(File.join(FIXTURE_DIR, 'hieradata', 'grafana.yaml.erb'))).result(binding)
data = YAML.load(default_hieradata).merge(YAML.load(grafana_hieradata))

describe 'the grafana server' do
  before(:all) do
    write_hieradata_to(grafana, data)

    # This would normally be required on the Puppet compile masters.
    if grafana[:type] == 'aio'
      on(grafana, '/opt/puppetlabs/bin/puppet resource package toml ensure=present provider=puppet_gem')
    else
      grafana.install_package('rubygem-toml')
    end
  end

  let(:curl_base_args) { '--cacert /etc/pki/simp-testing/pki/cacerts/cacerts.pem ' }
  let(:curl_rest_args) { curl_base_args + '-H "Accept: application/json" -H "Content-Type: application/json" ' }

  context 'with SIMP-default parameters' do
    let(:manifest) do
      <<-EOS
        class { 'simp_grafana':
          cfg => { security => { admin_password => 'admin' } },
        }

        # Allow SSH from the standard Vagrant nets
        iptables::listen::tcp_stateful { 'allow_ssh':
          trusted_nets => hiera('simp_options::trusted_nets'),
          dports       => 22,
        }
      EOS
    end

    it 'applies without errors' do
      # this first apply will fail because the grafana RPM installation
      # (managed by the grafana module) requires 'yum install grafana -y'
      # to be called twice. The first time it complains that the grafana
      # GPG key could not be found, but then succeeds the second time.
      apply_manifest_on(grafana, manifest, :accept_all_exit_codes => true)

      # We must do this twice before it becomes idempotent due to a bug in
      # pupmod-simp-iptables with SELinux
      apply_manifest_on(grafana, manifest, :catch_failures => true)
      apply_manifest_on(grafana, manifest, :catch_failures => true)
      on(grafana, 'rpm -q grafana')
    end

    it 'is idempotent' do
      apply_manifest_on(grafana, manifest, :catch_changes => true)
    end

    describe package('grafana') do
      it { is_expected.to be_installed }
    end

    describe service('grafana-server') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe x509_certificate("/etc/pki/simp_apps/grafana/x509/public/#{grafana_fqdn}.pub") do
      it { is_expected.to be_certificate }
    end

    describe file("/etc/pki/simp_apps/grafana/x509/public/#{grafana_fqdn}.pub") do
      it { is_expected.to be_grouped_into 'grafana' }
      it { is_expected.to be_readable.by_user 'grafana' }
    end

    describe x509_private_key("/etc/pki/simp_apps/grafana/x509/private/#{grafana_fqdn}.pem") do
      it { is_expected.to be_valid }
      it { is_expected.to have_matching_certificate "/etc/pki/simp_apps/grafana/x509/public/#{grafana_fqdn}.pub" }
    end

    describe file("/etc/pki/simp_apps/grafana/x509/private/#{grafana_fqdn}.pem") do
      it { is_expected.to be_grouped_into 'grafana' }
      it { is_expected.to be_readable.by_user 'grafana' }
      it { is_expected.not_to be_readable.by 'others' }
    end

    describe port("#{grafana_port}") do
      it { is_expected.to be_listening }
    end

    describe iptables do
      it "allows traffic from `trusted_nets` to port #{grafana_port}" do
        on(grafana,'iptables -S LOCAL-INPUT')
        is_expected.to have_rule("-s 127.0.0.0/8 -p tcp -m state --state NEW -m tcp -m multiport --dports #{grafana_port} -m comment --comment \"SIMP:\" -j ACCEPT").
          with_chain('LOCAL-INPUT')
      end
    end

    it 'accepts connections' do
      curl_on(grafana, curl_base_args + "--verbose https://#{grafana_fqdn}:#{grafana_port}")
    end

    it 'rejects HTTP basic authentication' do
      curl_output   = curl_on(grafana, curl_base_args + "https://admin:admin@#{grafana_fqdn}:#{grafana_port}/api/login/ping").stdout
      json_response = JSON.parse(curl_output)
      expect(json_response['message']).to match('Unauthorized')
    end
  end

  context 'with HTTP basic authenication enabled' do
    let(:manifest) do
      <<-EOS
        class { 'simp_grafana':
          cfg => { 'auth.basic' => { enabled => true } },
        }

        # Allow SSH from the standard Vagrant nets
        iptables::listen::tcp_stateful { 'allow_ssh':
          trusted_nets => hiera('simp_options::trusted_nets'),
          dports       => 22,
        }
      EOS
    end

    it 'applies without errors' do
      apply_manifest_on(grafana, manifest, :catch_failures => true)
    end

    it 'is idempotent' do
      apply_manifest_on(grafana, manifest, :catch_changes => true)
    end
  end

  shared_examples_for 'an LDAP-enabled server' do
    it 'allows `testadmin` to authenticate' do
      login_args = curl_rest_args + "-d '{\"user\":\"testadmin\",\"email\":\"\",\"password\":\"123$%^qweRTY\"}' "
      login_args << "https://#{grafana_fqdn}:#{grafana_port}/login"
      login_output = JSON.parse(curl_on(grafana, login_args).stdout)
      expect(login_output['message']).to eq('Logged in')
    end

    it 'allows `testuser-allow` to authenticate' do
      login_args = curl_rest_args + "-d '{\"user\":\"testuser-allow\",\"email\":\"\",\"password\":\"123$%^qweRTY\"}' "
      login_args << "https://#{grafana_fqdn}:#{grafana_port}/login"
      login_output = JSON.parse(curl_on(grafana, login_args).stdout)
      expect(login_output['message']).to eq('Logged in')
    end

    it 'denies `testuser-deny`' do
      login_args = curl_rest_args + "-d '{\"user\":\"testuser-deny\",\"email\":\"\",\"password\":\"123$%^qweRTY\"}' "
      login_args << "https://#{grafana_fqdn}:#{grafana_port}/login"
      login_output = JSON.parse(curl_on(grafana, login_args).stdout)
      expect(login_output['message']).to eq('Invalid username or password')
    end

    it 'assigns `testadmin` the role of Admin in the Main organization' do
      user_fetch_args   = curl_rest_args + "https://admin:admin@#{grafana_fqdn}:#{grafana_port}/api/orgs/1/users"
      user_fetch_output = JSON.parse(curl_on(grafana, user_fetch_args).stdout)
      testadmin         = user_fetch_output.select { |user| user['login'] == 'testadmin' }[0]
      expect(testadmin['role']).to eq('Admin')
    end

    it 'assigns `testuser-allow` the role of Editor in the Main organization' do
      user_fetch_args   = curl_rest_args + "https://admin:admin@#{grafana_fqdn}:#{grafana_port}/api/orgs/1/users"
      user_fetch_output = JSON.parse(curl_on(grafana, user_fetch_args).stdout)
      testuser_allow    = user_fetch_output.select { |user| user['login'] == 'testuser-allow' }[0]
      expect(testuser_allow['role']).to eq('Editor')
    end
  end

  context 'with LDAP enabled via the global catalyst' do
    before(:all) do
      write_hieradata_to(grafana, data.merge({'simp_options::ldap' => true}))
    end

    let(:manifest) do
      <<-EOS
        class { 'simp_grafana':
          cfg => { 'auth.basic' => { enabled => true } },
        }

        # Allow SSH from the standard Vagrant nets
        iptables::listen::tcp_stateful { 'allow_ssh':
          trusted_nets => hiera('simp_options::trusted_nets'),
          dports       => 22,
        }
      EOS
    end

    it 'applies without errors' do
      apply_manifest_on(grafana, manifest, :catch_failures => true)
    end

    it 'is idempotent' do
      apply_manifest_on(grafana, manifest, :catch_changes => true)
    end

    it_behaves_like 'an LDAP-enabled server'
  end

  context 'with LDAP enabled in the manifest' do
    let(:manifest) do
      <<-EOS
        class { 'simp_grafana':
          cfg => { 'auth.basic' => { enabled => true }, 'auth.ldap' => { enabled => true } },
        }

        # Allow SSH from the standard Vagrant nets
        iptables::listen::tcp_stateful { 'allow_ssh':
          trusted_nets => hiera('simp_options::trusted_nets'),
          dports       => 22,
        }
      EOS
    end

    it 'applies without errors' do
      apply_manifest_on(grafana, manifest, :catch_failures => true)
    end

    it 'is idempotent' do
      apply_manifest_on(grafana, manifest, :catch_changes => true)
    end

    it_behaves_like 'an LDAP-enabled server'
  end

  context 'with LDAP configured' do
    let(:manifest) do
      <<-EOS
        class { 'simp_grafana':
          cfg      => { 'auth.basic' => { enabled => true }, 'auth.ldap' => { enabled => true } },
          ldap_cfg => {
            verbose_logging => true,
            servers         => [
              {
                host                  => '#{simp_fqdn}',
                port                  => 636,
                use_ssl               => true,
                ssl_skip_verify       => true,
                bind_dn               => 'uid=grafana,ou=Services,dc=test',
                bind_password         => '123$%^qweRTY',
                search_filter         => '(uid=%s)',
                search_base_dns       => ['ou=People,dc=test'],
                group_search_filter   => '(&(objectClass=posixGroup)(memberUid=%s))',
                group_search_base_dns => ['ou=Group,dc=test'],
                attributes            => {
                  name      => 'givenName',
                  surname   => 'sn',
                  username  => 'uid',
                  member_of => 'gidNumber',
                  email     => 'mail',
                },
                group_mappings => [
                  { group_dn => '50000', org_role => 'Admin'  },
                  { group_dn => '50001', org_role => 'Editor' },
                ],
              },
            ],
          },
        }

        # Allow SSH from the standard Vagrant nets
        iptables::listen::tcp_stateful { 'allow_ssh':
          trusted_nets => hiera('simp_options::trusted_nets'),
          dports       => 22,
        }
      EOS
    end

    it 'applies without errors' do
      apply_manifest_on(grafana, manifest, :catch_failures => true)
    end

    it 'is idempotent' do
      apply_manifest_on(grafana, manifest, :catch_changes => true)
    end

    it_behaves_like 'an LDAP-enabled server'
  end

  context 'with a data source defined' do
    let(:manifest) do
      <<-EOS
        class { 'simp_grafana':
          cfg             => { 'auth.basic' => { enabled => true }, 'auth.ldap' => { enabled => true } },
          ldap_cfg        => {
            verbose_logging => true,
            servers         => [
              {
                host                  => '#{simp_fqdn}',
                port                  => 636,
                use_ssl               => true,
                ssl_skip_verify       => true,
                bind_dn               => 'uid=grafana,ou=Services,dc=test',
                bind_password         => '123$%^qweRTY',
                search_filter         => '(uid=%s)',
                search_base_dns       => ['ou=People,dc=test'],
                group_search_filter   => '(&(objectClass=posixGroup)(memberUid=%s))',
                group_search_base_dns => ['ou=Group,dc=test'],
                attributes            => {
                  name      => 'givenName',
                  surname   => 'sn',
                  username  => 'uid',
                  member_of => 'gidNumber',
                  email     => 'mail',
                },
                group_mappings => [
                  { group_dn => '50000', org_role => 'Admin'  },
                  { group_dn => '50001', org_role => 'Editor' },
                ],
              },
            ],
          },
        }

        # Allow SSH from the standard Vagrant nets
        iptables::listen::tcp_stateful { 'allow_ssh':
          trusted_nets => hiera('simp_options::trusted_nets'),
          dports       => 22,
        }

        # This datasource represents how we would typically
        # connect to Elasticsearch. Per Grafana's recommendation
        # we use the proxy access mode.
        #
        # FIXME:
        # Beginning with Grafana 4.6.2, TLS server verification
        # is turned on by default for communication with datasources.
        # Until we can figure out how to configure the datasource with
        # the appropriate cacert, we need to disable TLS server
        # verification by setting tlsSkipVerify to true.
        grafana_datasource { 'elasticsearch':
          ensure            => present,
          grafana_url       => 'https://#{grafana_fqdn}:#{grafana_port}',
          grafana_user      => 'admin',
          grafana_password  => 'admin',
          type              => 'elasticsearch',
          url               => 'https://#{elasticsearch_fqdn}:9200',
          access_mode       => 'proxy',
          database          => '[logstash-]YYYY.MM.DD',
          is_default        => true,
          json_data         => {
            esVersion     => 5,
            timeField     => '@timestamp',
            interval      => 'Daily',
            tlsSkipVerify => true,
          },
          require => Class['::grafana::service'],
        }
      EOS
    end

    it 'applies without errors' do
      apply_manifest_on grafana, manifest, :catch_failures => true
    end

    it 'is idempotent' do
      apply_manifest_on grafana, manifest, :catch_changes => true
    end

    it 'communicates with Elasticsearch' do
      # If the following proxy command to Elasticsearch doesn't work,
      # we are NOT properly configured to pull data from Elasticsearch!
      es_test_args = curl_rest_args
      es_test_args << "https://admin:admin@#{grafana_fqdn}:#{grafana_port}/api/datasources/proxy/1/logstash-#{Time.now.utc.strftime('%Y.%m.%d')}/_stats"
      curl_output = curl_on(grafana, es_test_args).stdout
      expect(curl_output).to match(/_shards/)
    end
  end

  context 'when the `::grafana::package_source` is set to a local file' do
    before(:all) do
      context_hieradata = ERB.new(File.read(File.join(FIXTURE_DIR, 'hieradata', 'grafana_local_package.yaml.erb'))).result(binding)
      write_hieradata_to(grafana, data.merge(YAML.load(context_hieradata)))

      on(grafana, 'yum remove -y grafana')
      grafana.install_package('yum-utils')
      on(grafana, 'cd /tmp; yumdownloader grafana')
      on(grafana, 'cd /tmp; mv grafana-*.rpm grafana_package.x86_64.rpm')
    end

    let(:manifest) do
      <<-EOS
        class { 'simp_grafana':
          install_method => 'package',
        }

        # Allow SSH from the standard Vagrant nets
        iptables::listen::tcp_stateful { 'allow_ssh':
          trusted_nets => hiera('simp_options::trusted_nets'),
          dports       => 22,
        }
      EOS
    end

    it 'applies without errors' do
      apply_manifest_on(grafana, manifest, :catch_failures => true)
    end

    it 'is idempotent' do
      apply_manifest_on(grafana, manifest, :catch_changes => true)
    end

    describe package('grafana') do
      it { is_expected.to be_installed }
    end
  end
end
