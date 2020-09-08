%define _prefix /usr/local

Name:		efmdemo
Version:	1.3
Release:	8%{?dist}
Summary:	EDB Failover Manager Demo on AWS

Group:		Productivity/Database/Tools
License:	GPL
URL:		www.enterprisedb.com
Vendor:		EDB
Packager:	Simon Anthony
Source0:	%{name}-%{version}.tar.gz

Requires: jq, libnotify, bash
BuildRequires: bash

BuildArch: noarch

%global debug_package %{nil}

%description
Supporting scripts and tools for EFM Demo on AWS


%prep
%setup -q


%build
%configure \
	--prefix=%{_prefix} \
	--bindir=%_bindir \
	--sbindir=%_sbindir \
	--datadir=%_datadir \
	--sysconfdir=%_sysconfdir \
	--libdir=%_libdir \
	--includedir=%_includedir \
	--localstatedir=%{_localstatedir} \
	--mandir=%{_prefix}/share/man 
make %{?_smp_mflags}


%install
[ %buildroot != "/" ] && rm -rf %buildroot
make DESTDIR=%buildroot install


%clean
[ %buildroot != "/" ] && rm -rf %buildroot


%files
%{_bindir}/*
%{_mandir}/*

%changelog

