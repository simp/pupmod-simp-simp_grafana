require 'spec_helper_acceptance'

test_name 'simp_grafana'

describe 'simp_grafana' do
  let(:manifest) do
    <<-EOS
      class { 'simp_grafana': }
    EOS
  end

  context 'default parameters' do
    # Using puppet_apply as a helper
    it 'should work with no errors' do
      apply_manifest(manifest, :catch_failures => true)
    end

    it 'should be idempotent' do
      apply_manifest(manifest, :catch_changes => true)
    end

    describe package('grafana') do
      it { is_expected.to be_installed }
    end

    describe service('grafana-server') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end
end
