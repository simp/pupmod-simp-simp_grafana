# Variables:
#
# PUPPET_VERSION   | specifies the version of the puppet gem to load
# SIMP_GEM_SERVERS | a space/comma delimited list of rubygem servers
puppetversion = ENV.key?('PUPPET_VERSION') ? ENV['PUPPET_VERSION'].to_s : '~>3'
gem_sources   = ENV.key?('SIMP_GEM_SERVERS') ? ENV['SIMP_GEM_SERVERS'].split(/[, ]+/) : ['https://rubygems.org']

PUPPET_VERSION = puppetversion.sub(/[~><=]{1,2}/, '').strip

gem_sources.each { |gem_source| source gem_source }

group :test do
  gem 'rake'
  gem 'puppet', puppetversion
  gem 'rspec', '< 3.2.0'
  gem 'rspec-puppet'
  gem 'puppetlabs_spec_helper'
  gem 'metadata-json-lint'
  gem 'simp-rspec-puppet-facts'
  gem 'puppet-lint', '>= 1.1.0',                                   :require => false
  gem 'puppet-lint-absolute_classname-check',                      :require => false
  gem 'puppet-lint-leading_zero-check',                            :require => false
  gem 'puppet-lint-trailing_comma-check',                          :require => false
  gem 'puppet-lint-version_comparison-check',                      :require => false
  gem 'puppet-lint-classes_and_types_beginning_with_digits-check', :require => false
  gem 'puppet-lint-unquoted_string-check',                         :require => false
  gem 'puppet-lint-resource_reference_syntax',                     :require => false

  # dependency hacks:
  gem 'fog-google', '~> 0.0.9' # 0.1 dropped support for ruby 1.9

  # See[ HI-505](https://tickets.puppetlabs.com/browse/HI-505)
  if Gem::Version.new(PUPPET_VERSION) >= Gem::Version.new('4.0')
    gem 'hiera', '~> 3.0.0'
  end

  # simp-rake-helpers does not suport puppet 2.7.X
  if ENV['PUPPET_VERSION'].to_s.scan(/\d+/).first != '2' &&
     # simp-rake-helpers and ruby 1.8.7 bomb Travis tests
     # TODO: fix upstream deps (parallel in simp-rake-helpers)
     RUBY_VERSION.sub(/\.\d+$/, '') != '1.8'
    gem 'simp-rake-helpers'
  end
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.2')
    gem 'rubocop', :require => false
  end
end

group :development do
  gem 'travis'
  gem 'travis-lint'
  gem 'vagrant-wrapper'
  gem 'puppet-blacksmith'
  gem 'guard-rake'
  gem 'pry'
  gem 'pry-doc'
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.2')
    gem 'listen', '< 3.1', :require => false
  end
end

group :system_tests do
  gem 'beaker'
  gem 'beaker-rspec'

  # 1.0.5 introduces FIPS-first acc tests
  gem 'simp-beaker-helpers', '>= 1.0.5'

  # dependency hacks:
  # NOTE: Workaround because net-ssh 2.10 is busting beaker
  # lib/ruby/1.9.1/socket.rb:251:in `tcp': wrong number of arguments (5 for 4) (ArgumentError)
  gem 'net-ssh', '~> 2.9.0'

  # XXX: Workaround for `wrong number of arguments (0 for 1)` error on all serverspec/specinfra tests.
  # See https://github.com/puppetlabs/ruby-hocon/issues/75 for details.
  gem 'specinfra', '~> 2.28.0'
end
