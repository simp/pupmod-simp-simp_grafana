require 'beaker-rspec'
require 'erb'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

FIXTURE_DIR = File.expand_path(File.join(__FILE__, '..', 'fixtures'))

unless ENV['BEAKER_provision'] == 'no'

  # Misc tasks that need to run on every host
  hosts.each do |host|
    # Install Puppet
    if host.is_pe?
      install_pe
    else
      install_puppet
    end

    # Enable strict variables
    if ENV['STRICT_VARIABLES'] == 'yes'
      on host, 'puppet config set strict_variables true'
    end

    # Enable trusted facts on Puppet 3.x
    if ENV['TRUSTED_NODE_DATA'] == 'yes' && Gem::Version.new(fact_on(host, 'puppetversion')) <= Gem::Version.new('4.0')
      on host, 'puppet config set trusted_node_data true'
    end
  end
end

RSpec.configure do |c|
  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    simp_server = only_host_with_role(hosts, 'simp_server')

    # ensure that environment OS is ready on each host
    fix_errata_on hosts

    # Install modules and dependencies from spec/fixtures/modules
    copy_fixture_modules_to hosts

    unless ENV['BEAKER_provision'] == 'no'
      # Generate and install PKI certificates on each SUT
      Dir.mktmpdir do |cert_dir|
        keydist_dir = File.join(cert_dir, 'pki', 'keydist')

        run_fake_pki_ca_on simp_server, hosts, cert_dir

        hosts.each do |sut|
          on sut, 'mkdir -p /etc/puppet/modules/pki/files'
          scp_to sut, keydist_dir, '/etc/puppet/modules/pki/files/'
          copy_pki_to sut, cert_dir, '/etc/pki/simp-testing'
        end
      end

      copy_keydist_to simp_server
    end
  end
end
