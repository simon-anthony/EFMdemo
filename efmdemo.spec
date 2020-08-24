Name:		efm-demo
Version:	1.1
Release:	1%{?dist}
Summary:	EDB Failover Manager Demo on AWS

Group:		Productivity/Database/Tools
License:	GPL
URL:		www.enterprisedb.com
Vendor:		EDB
Packager:	Simon Anthony
Source0:	%{name}-%{version}.tar.gz
BuildRoot:  %_topdir/BUILDROOT/%{name}-%{version}-%{release}-build

BuildRequires: jq, lib-notify
Requires:	

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
	--localstatedir=/var/%{_prefix} \
	--mandir=%{_prefix}/share/man 
make %{?_smp_mflags}


%install
[ ${RPM_BUILD_ROOT} != "/" ] && rm -rf ${RPM_BUILD_ROOT}
make DESTDIR=${RPM_BUILD_ROOT} install


%clean
[ ${RPM_BUILD_ROOT} != "/" ] && rm -rf ${RPM_BUILD_ROOT}


%files
%{_bindir}/*


%changelog

