#
# spec file for package yast2-sap-ha
#
# Copyright (c) 2023 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#


Name:           yast2-sap-ha
Version:        5.0.2
Release:        0
BuildArch:      noarch
Source0:        %{name}-%{version}.tar.bz2
Source1:        yast2-sap-ha-rpmlintrc

Requires:       conntrack-tools
Requires:       corosync
Requires:       corosync-qdevice
Requires:       crmsh
Requires:       csync2
Requires:       hawk2
Requires:       pacemaker
Requires:       rubygem(%{rb_default_ruby_abi}:xmlrpc)
Requires:       yast2
Requires:       yast2-cluster >= 4.4.4
Requires:       yast2-ruby-bindings
Requires:       yast2-ntp-client
# for opening URLs
Requires:       xdg-utils
# for handling the SSH client
Requires:       expect
Requires:       firewalld
Requires:       openssh
%ifarch x86_64 ppc64le
Requires:       HANA-Firewall >= 2.0.3
%endif
Requires:       util-linux
Requires:       SAPHanaSR
Requires:       kmod
# for pidof
Requires:       sysvinit-tools

BuildRequires:  csync2
BuildRequires:  firewalld
BuildRequires:  kmod
BuildRequires:  rubygem(%{rb_default_ruby_abi}:rspec)
BuildRequires:  rubygem(%{rb_default_ruby_abi}:xmlrpc)
BuildRequires:  rubygem(%{rb_default_ruby_abi}:yast-rake)
BuildRequires:  sysvinit-tools
BuildRequires:  update-desktop-files
BuildRequires:  util-linux
BuildRequires:  yast2
BuildRequires:  yast2-cluster
BuildRequires:  yast2-devtools
BuildRequires:  yast2-ntp-client
BuildRequires:  yast2-packager
BuildRequires:  yast2-ruby-bindings
Summary:        SUSE High Availability Setup for SAP Products
License:        GPL-2.0-only
Group:          System/YaST
URL:            http://www.suse.com

%description
A YaST2 module to enable high availability for SAP HANA installations.

%prep
%setup -n %{name}-%{version}

%check
rake test:unit

%build

%install
mkdir -p %{buildroot}%{yast_vardir}/sap_ha/

rake install DESTDIR="%{buildroot}"

%post

%files
%defattr(-,root,root)
%doc %yast_docdir
%yast_desktopdir
%yast_clientdir
%yast_libdir
%{yast_dir}/data/sap_ha/
%{yast_vardir}/sap_ha/
%{yast_scrconfdir}/*.scr
%{yast_ybindir}

%changelog
