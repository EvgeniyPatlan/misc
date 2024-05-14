%undefine _debugsource_packages
%define debug_package %{nil}

%global sname citus
%global pgmajorversion 16

%ifarch ppc64 ppc64le s390 s390x armv7hl
 %if 0%{?rhel} && 0%{?rhel} == 7
  %{!?llvm:%global llvm 0}
 %else
  %{!?llvm:%global llvm 1}
 %endif
%else
 %{!?llvm:%global llvm 1}
%endif

Name:           percona-%{sname}_%{pgmajorversion}
Version:        12.1.3
Release:        1%{dist}
License:        AGPLv3
URL:            https://github.com/citusdata/%{sname}
Source0:        percona-citus-%{version}.tar.gz
BuildRequires:  percona-postgresql%{pgmajorversion}-devel libxml2-devel
BuildRequires:  libxslt-devel openssl-devel pam-devel readline-devel
BuildRequires:  libcurl-devel libzstd-devel
Requires:       percona-postgresql%{pgmajorversion}-server
Summary:        PostgreSQL extension that transforms Postgres into a distributed database

Provides:       %{sname} = %{version}-%{release}
Obsoletes:      %{sname} <= %{version}-%{release}
Epoch:          1

%if 0%{?suse_version} >= 1315
Requires:       libzstd1
%else
Requires:       libzstd
%endif

%description
Citus horizontally scales PostgreSQL across commodity servers
using sharding and replication. Its query engine parallelizes
incoming SQL queries across these servers to enable real-time
responses on large datasets.

Citus extends the underlying database rather than forking it,
which gives developers and enterprises the power and familiarity
of a traditional relational database. As an extension, Citus
supports new PostgreSQL releases, allowing users to benefit from
new features while maintaining compatibility with existing
PostgreSQL tools. Note that Citus supports many (but not all) SQL
Summary:        Citus development header files and libraries
commands.

%package devel
Requires:       %{name}%{?_isa} = %{version}-%{release}
Summary:        Citus devel package

%description devel
This package includes development libraries for Citus.

%if %llvm
%package llvmjit
Summary:        Just-in-time compilation support for Citus
Requires:       %{name}%{?_isa} = %{version}-%{release}
%if 0%{?rhel} && 0%{?rhel} == 7
# Packages come from EPEL and SCL:
%ifarch aarch64
BuildRequires:  llvm-toolset-7.0-llvm-devel >= 7.0.1 llvm-toolset-7.0-clang >= 7.0.1
%else
BuildRequires:  llvm5.0-devel >= 5.0 llvm-toolset-7-clang >= 4.0.1
%endif
%endif
%if 0%{?rhel} && 0%{?rhel} >= 8
# Packages come from Appstream:
BuildRequires:  llvm-devel >= 8.0.1 clang-devel >= 8.0.1
%endif
%if 0%{?fedora}
BuildRequires:  llvm-devel >= 5.0 clang-devel >= 5.0
%endif
%if 0%{?suse_version} >= 1315 && 0%{?suse_version} <= 1499
BuildRequires:  llvm6-devel clang6-devel
%endif
%if 0%{?suse_version} >= 1500
BuildRequires:  llvm13-devel clang13-devel
%endif

%description llvmjit
This packages provides JIT support for Citus
%endif

%prep
%setup -q -n percona-%{sname}-%{version}

%build
%configure PG_CONFIG=%{pginstdir}/bin/pg_config --with-security-flags
make %{?_smp_mflags}

%install
%make_install
# Install documentation with a better name:
%{__mkdir} -p %{buildroot}%{pginstdir}/doc/extension
%{__cp} README.md %{buildroot}%{pginstdir}/doc/extension/README-%{sname}.md

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc CHANGELOG.md
%if 0%{?rhel} && 0%{?rhel} <= 6
%doc LICENSE
%else
%license LICENSE
%endif
%doc %{pginstdir}/doc/extension/README-%{sname}.md
%{pginstdir}/lib/%{sname}.so
%{pginstdir}/lib/%{sname}_columnar.so
%{pginstdir}/lib/citus_decoders/*.so
%{pginstdir}/lib/citus_*.so
%{pginstdir}/bin/pg_send_cancellation
%{pginstdir}/share/extension/%{sname}-*.sql
%{pginstdir}/share/extension/%{sname}.control
%{pginstdir}/share/extension/%{sname}_columnar-*.sql
%{pginstdir}/share/extension/columnar-*.sql
%{pginstdir}/share/extension/%{sname}_columnar.control
%{pginstdir}/lib/bitcode/citus_columnar/*.bc
%{pginstdir}/lib/bitcode/citus_columnar/safeclib/*.bc
%{pginstdir}/lib/bitcode/citus_pgoutput/*.bc
%{pginstdir}/lib/bitcode/citus_wal2json/*.bc

%files devel
%defattr(-,root,root,-)
%{pginstdir}/include/server/citus_version.h
%{pginstdir}/include/server/distributed/*.h

%if %llvm
%files llvmjit
    %{pginstdir}/lib/bitcode/%{sname}*.bc
    %{pginstdir}/lib/bitcode/%{sname}/*.bc
    %{pginstdir}/lib/bitcode/%{sname}/*/*.bc
    %{pginstdir}/lib/bitcode/%{sname}_columnar/*
%endif

%changelog
* Tue May 14 2024 Evgeniy Patlan <evgeniy.patlan@percona.com> 12.1.3-1
- Update version

* Fri Jun  9 2023 Evgeniy Patlan <evgeniy.patlan@percona.com> 11.2.1-1
- Initial build