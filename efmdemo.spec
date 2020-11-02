%define _prefix /usr/local

Name:		efmdemo
Version:	2.4
Release:	1%{?dist}
Summary:	EDB Failover Manager Demo on AWS, GCP and local

Group:		Productivity/Database/Tools
License:	GPL
URL:		www.enterprisedb.com
Vendor:		EDB
Packager:	Simon Anthony
Source0:	%{name}-%{version}.tar.gz

Requires: jq, libnotify, bash, bind-utils
BuildRequires: bash

BuildArch: noarch

%global debug_package %{nil}

%description
Supporting scripts and tools for EFM Demo on AWS, GCP and local


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


%post
echo ">>> Running post <<<"
cloud=local
[ -x /usr/local/bin/aws ] && cloud=aws
[ -x /usr/bin/gcloud ] && cloud=gcp

ln -fs %{_datadir}/efm/$cloud/script/efm-notify %{_bindir}
ln -fs %{_datadir}/efm/$cloud/script/efm-post-promotion %{_bindir}
ln -fs %{_datadir}/efm/$cloud/script/efm-remote-post-promotion %{_bindir}


%preun
echo ">>> Running preun <<<"
cloud=local
[ -x /usr/local/bin/aws ] && cloud=aws
[ -x /usr/bin/gcloud ] && cloud=gcp

[ -r %{_datadir}/efm/$cloud/script/efm-notify ] || rm -f %{_bindir}/efm-notify
[ -r %{_datadir}/efm/$cloud/script/efm-post-promotion ] || rm -f %{_bindir}/efm-post-promotion
[ -r %{_datadir}/efm/$cloud/script/efm-remote-post-promotion ] || rm -f %{_bindir}/efm-remote-post-promotion
:


%files
%{_bindir}/*
%{_datadir}/*


%changelog

