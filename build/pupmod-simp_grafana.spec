Summary: A profile module to integrate Grafana with SIMP
Name: pupmod-simp_grafana
Version: 0.1.0
Release: 0
License: Apache License, Version 2.0
Group: Applications/System
Source: %{name}-%{version}-%{release}.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Requires: pupmod-iptables >= 2.0.0-0
Requires: pupmod-simplib  >= 1.0.0-0
Requires: puppet >= 3.3.0
Buildarch: noarch

Prefix: /etc/puppet/environments/simp/modules

%description
A profile module to integrate Grafana with SIMP

%prep
%setup -q

%build

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}/simp_grafana

dirs='files lib manifests templates'
for dir in $dirs; do
  test -d $dir && cp -r $dir %{buildroot}/%{prefix}/simp_grafana
done

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}/simp_grafana

%files
%defattr(0640,root,puppet,0750)
%{prefix}/simp_grafana

%post
#!/bin/sh

%postun
# Post uninstall stuff

%changelog
* Tue Jun 21 2016 simp - 0.1.0-0
- Initial package.
