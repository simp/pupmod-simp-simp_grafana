[![License](http://img.shields.io/license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/simp_grafana.svg)](https://forge.puppetlabs.com/simp/simp_grafana)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/simp_grafana.svg)](https://forge.puppetlabs.com/simp/simp_grafana)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-simp_grafana.svg)](https://travis-ci.org/simp/pupmod-simp-simp_grafana)

Table of Contents
=================

1.  [Module Description - What the module does and why it is
    useful](#module-description)
2.  [Setup - The basics of getting started with simp\_grafana](#setup)
    - [What simp\_grafana affects](#what-simp_grafana-affects)
    - [Setup requirements](#setup-requirements)
    - [Beginning with simp\_grafana](#beginning-with-simp_grafana)
3.  [Usage - Configuration options and additional functionality](#usage)
4.  [Reference - An under-the-hood peek at what the module is doing and
    how](#reference)
5.  [Limitations - OS compatibility, etc.](#limitations)
6.  [Development - Guide for contributing to the module](#development)
    - [Acceptance Tests - Beaker env variables](#acceptance-tests)

Module Description
==================

[Grafana](http://grafana.org/) is a web-based metric and analytics
display tool, frequently used for log analysis. This module acts as a
SIMP wrapper (or "profile") for the Puppet, Inc. Approved Grafana
module written and maintained by Bill Fraser and maintained by Vox
Pupuli. It sets a baseline of secure defaults and integrates Grafana
with other SIMP components.

This is a SIMP module
=====================

This module is a component of the [System Integrity ManagementPlatform](https://simp-project.com),
a compliance-management framework built on Puppet.

If you find any issues, they can be submitted to our
[JIRA](https://simp-project.atlassian.net/).

Please read our [Contribution Guide](http://simp-doc.readthedocs.io/en/stable/contributors_guide/index.html).

This module is optimally designed for use within a larger SIMP
ecosystem, but it can be used independently:

- As a SIMP wrapper module, the defaults use the larger SIMP ecosystem
  to manage security compliance settings from the Puppet server.
- If used independently, all SIMP-managed security subsystems may be
  disabled via the `simp_options::firewall`, `simp_options::pki`, and `simp_options::ldap`
  settings.


> If SIMP integration is not required, use of this module is
> discouraged; direct use of the component Grafana module is advised.

Setup
=====

What simp\_grafana affects
--------------------------

- The Grafana package
- IPTables rules
- Linux Capabilities for the Grafana server daemon
- PKI certificates in Grafana's `/etc/grafana` directory

Setup Requirements
------------------

Because this is a SIMP profile module, it assumes basic SIMP components
are already deployed. Namely, it requires the
[IPTables](https://github.com/simp/pupmod-simp-iptables) and
[PKI](https://github.com/simp/pupmod-simp-pki) modules. Setup of those
modules is beyond the scope of this document. Please see the component
documentation for more details.

Beginning with simp\_grafana
----------------------------

Assuming SIMP is deployed, and an Internet connection is available to
download the package files to the intended Grafana server, use of this
module should be as simple as `include 'simp_grafana'`.

Usage
=====

Aside from the few "passthrough" parameters, any parameter in the
component `grafana` class may be overloaded via Hiera. For example,
the install method may be changed like this:

```yaml
---
grafana::install_method: package
```

LDAP configuration
------------------

By default, while on a standard SIMP installation, LDAP authentication is enabled. However, installing 
this module on it's own will disable LDAP authentiaction by default, but defaults are pre-seeded for the SIMP OpenLDAP
server using the SIMP-standard Hiera keys. To use them, simply enable `simp_options::ldap`.

```puppet
# Manifest

include 'simp_grafana'
```

```yaml
# Hiera data
---
simp_options::ldap: true
```

Other `simp_options::ldap` settings will be required for this module to work outside of a SIMP installation, including:
* `simp_options::ldap::base_dn`
* `simp_options::ldap::bind_dn`
* `simp_options::ldap::bind_pw`
* `simp_options::pki`
* `simp_options::pki::source`
* `simp_options::ldap::uri`

This will also set up default group mappings for groups with the CNs:
* `simp_grafana_admins`
* `simp_grafana_editors`
* `simp_grafana_editors_ro`
* `simp_grafana_viewers`

If `$ldap` is set to true, the `toml` gem needs to be installed into the
puppetserver gemset. An RPM called `rubygem-puppetserver-toml` is
provided with SIMP 6.2 that automatically installs the gem and its
dependencies into the puppetserver. This RPM and its dependent RPMs can
be found in the 6\_X\_Dependencies yum repo, available on
[PackageCloud](https://packagecloud.io/simp-project/6_X_Dependencies).
Install this package using yum:

```shell
yum install -y rubygem-puppetserver-toml
```

>At present the module does not support config merging of servers in the
`ldap_cfg` parameter, so if any changes are made to the default server,
the entire server must be configured.

LDAP Config Settings
--------------------
SIMP utilizes 'smart' defaults to configure LDAP. If you are looking to utilize
a custom LDAP configuration, you can do so by using the `$ldap_cfg` variable.
The defaults will also not be used if `$ldap` or `simp_options::ldap` is false.
Make sure all needed options are set if specifying a custom `$ldap_cfg`.

Example:
```
class { 'simp_grafana':
  firewall        => true,
  pki             => true,
  trusted_nets    => ['10.255.0.0/16'],
  cfg             => { 'auth.ldap' => { enabled => true } },
  ldap_cfg        => {
    verbose_logging => true,
    servers         => [
      {
      host                  => 'ldap.example.com',
      port                  => 636,
      use_ssl               => true,
      bind_dn               => 'uid=grafana,ou=Services,dc=test',
      bind_password         => '123$%^qweRTY',
      search_filter         => '(uid=%s)',
      search_base_dns       => ['ou=People,dc=test'],
      group_search_filter   => '(&(objectClass=posixGroup)(memberUid=%s))',
      group_search_base_dns => ['ou=Group,dc=test'],
      attributes            => {
        name                => 'givenName',
        surname   => 'sn',
        username  => 'uid',
        member_of => 'gidNumber',
        email     => 'mail',
        },
      group_mappings => [
        { group_dn => 'admin', org_role => 'Admin'  },
        { group_dn => '50001', org_role => 'Editor' },
        ],
      },
    ],
  },
}
```

Network-isolated Setup
----------------------

If an Internet connection is not available, or if review of the package
files is desired, the `package_source` parameter to the component
Grafana module may be set. It takes a String that is valid for the
target package provider. For example, Yum can take URLs like
`http://example.com/path/to/rpm` or `file:///path/to/rpm`. If a local
HTTP server is unavailable, the file may be installed via Puppet to a
temporary directory. Here is an example:

```puppet
# Manifest

include 'simp_grafana'

file { '/tmp/grafana_package.rpm':
  ensure => file,
  source => 'puppet:///modules/files/rpms/grafana_package.rpm',
  before => Class['simp_grafana'],
}
```

```yaml
# Hiera data
---
grafana::package_source: 'file:///tmp/grafana_package.rpm'
```

Reference
=========

Please see the [REFERENCE.md](REFERENCE.md)
for the most up-to-date documentation.

Limitations
===========

This module has only been tested on CentOS 7, Red Hat Enterprise
Linux 7, and Oracle 7.

Development
===========

Please read our [Contribution Guide](http://simp-doc.readthedocs.io/en/stable/contributors_guide/index.html).

Acceptance tests
----------------

To run the system tests, you need [Vagrant](https://www.vagrantup.com/)
installed. Then, run:

```shell
bundle exec rake beaker:suites
```

Some environment variables may be useful:

```shell
BEAKER_debug=true
BEAKER_provision=no
BEAKER_destroy=no
BEAKER_use_fixtures_dir_for_modules=yes
BEAKER_fips=yes
BEAKER_spec_prep=no
```

- `BEAKER_debug`: show the commands being run on the STU and their
    output.
- `BEAKER_destroy=no`: prevent the machine destruction after the tests
    finish so you can inspect the state.
- `BEAKER_provision=no`: prevent the machine from being recreated.
    This can save a lot of time while you\'re writing the tests.
- `BEAKER_use_fixtures_dir_for_modules=yes`: cause all module
    dependencies to be loaded from the `spec/fixtures/modules`
    directory, based on the contents of `.fixtures.yml`. The contents of
    this directory are usually populated by
    `bundle exec rake spec_prep`. This can be used to run acceptance
    tests to run on isolated networks.
- `BEAKER_fips=yes`: enable FIPS-mode on the virtual instances. This
    can take a very long time, because it must enable FIPS in the kernel
    command-line, rebuild the initramfs, then reboot.
- `BEAKER_spec_prep=no`: don\'t populate `spec/fixtures/modules/`
    prior to executing the test suite. This can save time on subsequent
    runs when using `BEAKER_destroy=no BEAKER_provision=no`, however
    changes to the fixture modules will not take effect.
