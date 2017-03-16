#
# spec file for package yast2-sap-ha
#
# Copyright (c) 2016 SUSE Linux GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/

Name:           yast2-sap-ha
Version:        0.9.7
Release:        0
BuildArch:      noarch

Source0:        %{name}-%{version}.tar.bz2
Source1:        yast2-sap-ha-rpmlintrc

Requires:       yast2
Requires:       yast2-ruby-bindings
# for opening URLs
Requires:       xdg-utils
# for handling the SSH client
Requires:       expect
Requires:       openssh
Requires:       yast2-cluster
Requires:       yast2-ntp-client
Requires:       sap-installation-wizard
Requires:       ha-cluster-bootstrap
# for lsblk
Requires:       util-linux
# lsmod, modprobe
Requires:       kmod-compat
Requires:       SAPHanaSR
# configuration parser
Requires:       rubygem(%{rb_default_ruby_abi}:cfa)
# for pidof
Requires:       sysvinit-tools
Requires:       augeas-lenses

BuildRequires:  yast2
BuildRequires:  yast2-ruby-bindings
BuildRequires:  yast2-devtools
BuildRequires:  yast2-packager
BuildRequires:  rubygem(%{rb_default_ruby_abi}:cfa)
BuildRequires:  update-desktop-files
BuildRequires:  rubygem(%{rb_default_ruby_abi}:yast-rake)
BuildRequires:  rubygem(%{rb_default_ruby_abi}:rspec)
BuildRequires:  yast2-ntp-client
BuildRequires:  yast2-cluster
BuildRequires:  kmod-compat
BuildRequires:  util-linux
BuildRequires:  sysvinit-tools
BuildRequires:  augeas-lenses

Group:          System/YaST
License:        GPL-2.0
Summary:        SUSE High Availability Setup for SAP Products
URL:            http://www.suse.com

%description
A YaST2 module to enable high availability for SAP HANA and SAP NetWeaver installations.

%prep
%define augeas_dir %{_datarootdir}/augeas/lenses/dist
%setup -n %{name}-%{version}

%check
rake test:unit

%build

%install
mkdir -p %{buildroot}%{yast_dir}/data/sap_ha/
mkdir -p %{buildroot}%{yast_vardir}/sap_ha/
mkdir -p %{yast_scrconfdir}
mkdir -p %{buildroot}%{augeas_dir}

rake install DESTDIR="%{buildroot}"
# wizard help files
install -m 644 data/*.html %{buildroot}%{yast_dir}/data/sap_ha/
# ruby templates
install -m 644 data/*.erb %{buildroot}%{yast_dir}/data/sap_ha/
# HA scenarios definitions
install -m 644 data/scenarios.yaml %{buildroot}%{yast_dir}/data/sap_ha/
# SSH invocation wrapper
install -m 755 data/check_ssh.expect %{buildroot}%{yast_dir}/data/sap_ha/
# Augeas lens for SAP INI files
install -m 644 data/sapini.aug %{buildroot}%{augeas_dir}

%files
%defattr(-,root,root)
%doc %yast_docdir
%yast_desktopdir
%yast_clientdir
%yast_libdir
%{yast_dir}/data/sap_ha/
%{yast_vardir}/sap_ha/
%{yast_scrconfdir}/*.scr
%{augeas_dir}/sapini.aug

%changelog
