require 'spec_helper_acceptance'
require 'time'

test_name 'fake_elasticsearch_server'

elasticsearch_server = only_host_with_role(hosts, 'elasticsearch_server')

fqdn = fact_on(elasticsearch_server, 'fqdn')

describe 'The fake Elasticsearch server' do
  before(:all) do
    default_hieradata   = ERB.new(File.read(File.join(FIXTURE_DIR, 'hieradata', 'default.yaml.erb'))).result(binding)
    es_server_hieradata = ERB.new(File.read(File.join(FIXTURE_DIR, 'hieradata', 'elasticsearch_server.yaml.erb'))).result(binding)

    # NOTE: The `context` terminus is for per-context blocks.  If used, be sure
    # it is filled with an empty YAML document (`---\n`) in the `after(:all)`
    # hook for the context so it doesn't effect subsequent contexts.
    write_hiera_config_on elasticsearch_server, %W(context #{fqdn} default)

    write_hieradata_to elasticsearch_server, default_hieradata, 'default'
    write_hieradata_to elasticsearch_server, es_server_hieradata, fqdn
    write_hieradata_to elasticsearch_server, "---\n", 'context'
  end

  let(:es_server_manifest) { File.open(File.join(FIXTURE_DIR, 'manifests', 'elasticsearch_server.pp')).read }
  let(:curl_args) do
    args = '--cacert /etc/pki/simp-testing/pki/cacerts/cacerts.pem '
    args << '-H "Accept: application/json" -H "Content-Type: application/json" '
    args << "-X POST -d '{\"message\":\"GRAFANA TEST MESSAGE\",\"@timestamp\":\"#{Time.now.utc.iso8601}\",\"@version\":\"2\"}' "
    args << "https://#{fqdn}:9200/logstash-#{Time.now.utc.strftime('%Y.%m.%d')}/logs"
    args
  end

  it 'installs without errors' do
    # We must do this twice before it becomes idempotent due to a bug in
    # pupmod-simp-iptables with SELinux
    apply_manifest_on elasticsearch_server, es_server_manifest, :catch_failures => true
    apply_manifest_on elasticsearch_server, es_server_manifest, :catch_failures => true
  end

  it 'executes Puppet idempotently' do
    apply_manifest_on elasticsearch_server, es_server_manifest, :catch_changes => true
  end

  it 'populates with fake data' do
    curl_on elasticsearch_server, curl_args
  end
end
