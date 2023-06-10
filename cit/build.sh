#!/usr/bin/env bash

shell_quote_string() {
  echo "$1" | sed -e 's,\([^a-zA-Z0-9/_.=-]\),\\\1,g'
}

usage () {
    cat <<EOF
Usage: $0 [OPTIONS]
    The following options may be given :
        --builddir=DIR      Absolute path to the dir where all actions will be performed
        --get_sources       Source will be downloaded from github
        --build_src_rpm     If it is set - src rpm will be built
        --build_src_deb  If it is set - source deb package will be built
        --build_rpm         If it is set - rpm will be built
        --build_deb         If it is set - deb will be built
        --install_deps      Install build dependencies(root privilages are required)
        --branch            Branch for build
        --repo              Repo for build
        --help) usage ;;
Example $0 --builddir=/tmp/BUILD --get_sources=1 --build_src_rpm=1 --build_rpm=1
EOF
        exit 1
}

append_arg_to_args () {
  args="$args "$(shell_quote_string "$1")
}

parse_arguments() {
    pick_args=
    if test "$1" = PICK-ARGS-FROM-ARGV
    then
        pick_args=1
        shift
    fi

    for arg do
        val=$(echo "$arg" | sed -e 's;^--[^=]*=;;')
        case "$arg" in
            --builddir=*) WORKDIR="$val" ;;
            --build_src_rpm=*) SRPM="$val" ;;
            --build_src_deb=*) SDEB="$val" ;;
            --build_rpm=*) RPM="$val" ;;
            --build_deb=*) DEB="$val" ;;
            --get_sources=*) SOURCE="$val" ;;
            --branch=*) BRANCH="$val" ;;
            --repo=*) REPO="$val" ;;
            --install_deps=*) INSTALL="$val" ;;
            --help) usage ;;
            *)
              if test -n "$pick_args"
              then
                  append_arg_to_args "$arg"
              fi
              ;;
        esac
    done
}

check_workdir(){
    if [ "x$WORKDIR" = "x$CURDIR" ]
    then
        echo >&2 "Current directory cannot be used for building!"
        exit 1
    else
        if ! test -d "$WORKDIR"
        then
            echo >&2 "$WORKDIR is not a directory."
            exit 1
        fi
    fi
    return
}

get_sources(){
    cd "${WORKDIR}"
    if [ "${SOURCE}" = 0 ]; then
        echo "Sources will not be downloaded"
        return 0
    fi
    PRODUCT=percona-citus
    echo "PRODUCT=${PRODUCT}" > percona-citus.properties

    PRODUCT_FULL=${PRODUCT}-${VERSION}
    echo "PRODUCT_FULL=${PRODUCT_FULL}" >> percona-citus.properties
    echo "VERSION=${VERSION}" >> percona-citus.properties
    echo "BUILD_NUMBER=${BUILD_NUMBER}" >> percona-citus.properties
    echo "BUILD_ID=${BUILD_ID}" >> percona-citus.properties
    git clone "$REPO"
    retval=$?
    if [ $retval != 0 ]
    then
        echo "There were some issues during repo cloning from github. Please retry one more time"
        exit 1
    fi
    mv citus ${PRODUCT}-${VERSION}
    cd ${PRODUCT}-${VERSION}
    if [ ! -z "$BRANCH" ]
    then
        git reset --hard
        git clean -xdf
        git checkout "$BRANCH"
    fi
    REVISION=$(git rev-parse --short HEAD)
    echo "REVISION=${REVISION}" >> ${WORKDIR}/percona-citus.properties
    rm -fr debian rpm
    mkdir debian
    cd debian
        echo "9" > compat
        wget https://raw.githubusercontent.com/EvgeniyPatlan/misc/main/cit/debian/NOTICE
        wget https://raw.githubusercontent.com/EvgeniyPatlan/misc/main/cit/debian/control.in
        wget https://raw.githubusercontent.com/EvgeniyPatlan/misc/main/cit/debian/rules
        wget https://raw.githubusercontent.com/EvgeniyPatlan/misc/main/cit/debian/copyright
        wget https://raw.githubusercontent.com/EvgeniyPatlan/misc/main/cit/debian/docs
        wget https://raw.githubusercontent.com/EvgeniyPatlan/misc/main/cit/debian/pgversions
        wget https://raw.githubusercontent.com/EvgeniyPatlan/misc/main/cit/debian/control
        echo "15+"> pgversions
    cd ../
    mkdir rpm
    cd rpm
        wget https://raw.githubusercontent.com/EvgeniyPatlan/misc/main/cit/percona-citus.spec
    cd ../
    cd ${WORKDIR}
    #
    source percona-citus.properties
    #

    tar --owner=0 --group=0 --exclude=.* -czf ${PRODUCT}-${VERSION}.tar.gz ${PRODUCT}-${VERSION}
    echo "UPLOAD=UPLOAD/experimental/BUILDS/${PRODUCT}-15/${PRODUCT_FULL}/${BRANCH}/${REVISION}/${BUILD_ID}" >> percona-citus.properties
    mkdir $WORKDIR/source_tarball
    mkdir $CURDIR/source_tarball
    cp ${PRODUCT}-${VERSION}.tar.gz $WORKDIR/source_tarball
    cp ${PRODUCT}-${VERSION}.tar.gz $CURDIR/source_tarball
    cd $CURDIR
    rm -rf percona-citus*
    return
}

get_system(){
    if [ -f /etc/redhat-release ]; then
        RHEL=$(rpm --eval %rhel)
        ARCH=$(echo $(uname -m) | sed -e 's:i686:i386:g')
        OS_NAME="el$RHEL"
        OS="rpm"
    else
        ARCH=$(uname -m)
        OS_NAME="$(lsb_release -sc)"
        OS="deb"
    fi
    return
}

install_deps() {
    if [ $INSTALL = 0 ]
    then
        echo "Dependencies will not be installed"
        return;
    fi
    if [ $( id -u ) -ne 0 ]
    then
        echo "It is not possible to instal dependencies. Please run as root"
        exit 1
    fi
    CURPLACE=$(pwd)

    if [ "x$OS" = "xrpm" ]; then
        yum -y install wget git rpmdevtools
        yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
        percona-release disable all
        percona-release enable ppg-15.3 testing
        yum -y install epel-release
        RHEL=$(rpm --eval %rhel)
        if [ x"$RHEL" = x7 ]; then
            yum -y install centos-release-scl
            INSTALL_LIST="devtoolset-8-gcc devtoolset-8-libstdc++-devel gcc percona-postgresql15-devel libxml2-devel libxslt-devel openssl-devel pam-devel readline-devel libcurl-devel libzstd-devel llvm5.0-devel llvm-toolset-7-clang lz4-devel"
            yum -y install ${INSTALL_LIST}
        else
            dnf module -y disable postgresql
            if [ x"$RHEL" = x8 ]; then
                dnf config-manager --set-enabled ol8_codeready_builder
                INSTALL_LIST="gcc clang-devel libcurl-devel libxml2-devel libxslt-devel libzstd-devel llvm-devel openssl-devel pam-devel percona-postgresql15-devel readline-devel lz4-devel"
                yum -y install ${INSTALL_LIST}
            else
                INSTALL_LIST="krb5-devel gcc clang-devel libcurl-devel libxml2-devel libxslt-devel libzstd-devel llvm-devel openssl-devel pam-devel percona-postgresql15-devel readline-devel lz4-devel"
                dnf config-manager --set-enabled ol9_codeready_builder
                yum -y install ${INSTALL_LIST}
            fi    
        fi
    else
       export DEBIAN=$(lsb_release -sc)
        export ARCH=$(echo $(uname -m) | sed -e 's:i686:i386:g')
        apt-get update || true
        apt-get -y install gnupg2 curl
        export DEBIAN_FRONTEND=noninteractive
        DEBIAN_FRONTEND=noninteractive apt-get -y install tzdata
        ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
        dpkg-reconfigure --frontend noninteractive tzdata
        wget https://repo.percona.com/apt/percona-release_1.0-27.generic_all.deb
        dpkg -i percona-release_1.0-27.generic_all.deb
        percona-release disable all
        percona-release enable ppg-15.3 testing
        apt-get update
        INSTALL_LIST="devscripts debhelper autotools-dev liblz4-dev libzstd-dev percona-postgresql-server-dev-all libedit-dev libpam0g-dev libselinux1-dev libxslt1-dev libssl-dev libkrb5-dev libicu-dev libcurl4-openssl-dev"
        until DEBIAN_FRONTEND=noninteractive apt-get -y --allow-unauthenticated install ${INSTALL_LIST}; do
            sleep 1
            echo "waiting"
        done
    fi
    return;
}

get_tar(){
    TARBALL=$1
    TARFILE=$(basename $(find $WORKDIR/$TARBALL -name 'percona-citus*.tar.gz' | sort | tail -n1))
    if [ -z $TARFILE ]
    then
        TARFILE=$(basename $(find $CURDIR/$TARBALL -name 'percona-citus*.tar.gz' | sort | tail -n1))
        if [ -z $TARFILE ]
        then
            echo "There is no $TARBALL for build"
            exit 1
        else
            cp $CURDIR/$TARBALL/$TARFILE $WORKDIR/$TARFILE
        fi
    else
        cp $WORKDIR/$TARBALL/$TARFILE $WORKDIR/$TARFILE
    fi
    return
}

get_deb_sources(){
    param=$1
    echo $param
    FILE=$(basename $(find $WORKDIR/source_deb -name "percona-citus*.$param" | sort | tail -n1))
    if [ -z $FILE ]
    then
        FILE=$(basename $(find $CURDIR/source_deb -name "percona-citus*.$param" | sort | tail -n1))
        if [ -z $FILE ]
        then
            echo "There is no sources for build"
            exit 1
        else
            cp $CURDIR/source_deb/$FILE $WORKDIR/
        fi
    else
        cp $WORKDIR/source_deb/$FILE $WORKDIR/
    fi
    return
}

build_srpm(){
    if [ $SRPM = 0 ]
    then
        echo "SRC RPM will not be created"
        return;
    fi
    if [ "x$OS" = "xdeb" ]
    then
        echo "It is not possible to build src rpm here"
        exit 1
    fi
    cd $WORKDIR
    get_tar "source_tarball"
    rm -fr rpmbuild
    ls | grep -v tar.gz | xargs rm -rf
    TARFILE=$(find . -name 'percona-citus*.tar.gz' | sort | tail -n1)
    SRC_DIR=${TARFILE%.tar.gz}
    #
    mkdir -vp rpmbuild/{SOURCES,SPECS,BUILD,SRPMS,RPMS}
    tar vxzf ${WORKDIR}/${TARFILE} --wildcards '*/rpm' --strip=1
    #
    cp -av rpm/* rpmbuild/SOURCES
    cp -av rpmbuild/SOURCES/percona-citus.spec rpmbuild/SPECS
    #
    mv -fv ${TARFILE} ${WORKDIR}/rpmbuild/SOURCES
    rpmbuild -bs --define "_topdir ${WORKDIR}/rpmbuild" --define "dist .generic" \
        --define "pgmajorversion 15" --define "pginstdir /usr/pgsql-15"  --define "pgpackageversion 15" \
        rpmbuild/SPECS/percona-citus.spec
    mkdir -p ${WORKDIR}/srpm
    mkdir -p ${CURDIR}/srpm
    cp rpmbuild/SRPMS/*.src.rpm ${CURDIR}/srpm
    cp rpmbuild/SRPMS/*.src.rpm ${WORKDIR}/srpm
    return
}

build_rpm(){
    if [ $RPM = 0 ]
    then
        echo "RPM will not be created"
        return;
    fi
    if [ "x$OS" = "xdeb" ]
    then
        echo "It is not possible to build rpm here"
        exit 1
    fi
    SRC_RPM=$(basename $(find $WORKDIR/srpm -name 'percona-citus*.src.rpm' | sort | tail -n1))
    if [ -z $SRC_RPM ]
    then
        SRC_RPM=$(basename $(find $CURDIR/srpm -name 'percona-citus*.src.rpm' | sort | tail -n1))
        if [ -z $SRC_RPM ]
        then
            echo "There is no src rpm for build"
            echo "You can create it using key --build_src_rpm=1"
            exit 1
        else
            cp $CURDIR/srpm/$SRC_RPM $WORKDIR
        fi
    else
        cp $WORKDIR/srpm/$SRC_RPM $WORKDIR
    fi
    cd $WORKDIR
    rm -fr rpmbuild
    mkdir -vp rpmbuild/{SOURCES,SPECS,BUILD,SRPMS,RPMS}
    cp $SRC_RPM rpmbuild/SRPMS/

    cd rpmbuild/SRPMS/
    #
    cd $WORKDIR
    RHEL=$(rpm --eval %rhel)
    ARCH=$(echo $(uname -m) | sed -e 's:i686:i386:g')
    if [ x"$RHEL" = x7 ]; then
        source /opt/rh/devtoolset-8/enable
    fi
    rpmbuild --define "_topdir ${WORKDIR}/rpmbuild" --define "dist .$OS_NAME" --define "pgmajorversion 15" --define "pginstdir /usr/pgsql-15" --define "pgpackageversion 15" --rebuild rpmbuild/SRPMS/$SRC_RPM

    return_code=$?
    if [ $return_code != 0 ]; then
        exit $return_code
    fi
    mkdir -p ${WORKDIR}/rpm
    mkdir -p ${CURDIR}/rpm
    cp rpmbuild/RPMS/*/*.rpm ${WORKDIR}/rpm
    cp rpmbuild/RPMS/*/*.rpm ${CURDIR}/rpm
}

build_source_deb(){
    if [ $SDEB = 0 ]
    then
        echo "source deb package will not be created"
        return;
    fi
    if [ "x$OS" = "xrpm" ]
    then
        echo "It is not possible to build source deb here"
        exit 1
    fi
    rm -rf percona-citus*
    get_tar "source_tarball"
    rm -f *.dsc *.orig.tar.gz *.debian.tar.gz *.changes
    #
    TARFILE=$(basename $(find . -name 'percona-citus*.tar.gz' | sort | tail -n1))
    DEBIAN=$(lsb_release -sc)
    ARCH=$(echo $(uname -m) | sed -e 's:i686:i386:g')
    tar zxf ${TARFILE}
    BUILDDIR=${TARFILE%.tar.gz}
    #
    
    mv ${TARFILE} ${PRODUCT}-${VERSION}_${VERSION}.orig.tar.gz
    cd ${BUILDDIR}

    cd debian
    rm -rf changelog
    echo "percona-citus-15 (${VERSION}) unstable; urgency=low" >> changelog
    echo "  * Initial Release." >> changelog
    echo "  -- EvgeniyPatlan <evgeniy.patlan@percona.com> $(date -R)" >> changelog

    cd ../
    
    dch -D unstable --force-distribution -v "${VERSION}-${DEB_RELEASE}" "Update to new Percona Platform for PostgreSQL version ${VERSION}.${RELEASE}-${DEB_RELEASE}"
    dpkg-buildpackage -S
    cd ../
    mkdir -p $WORKDIR/source_deb
    mkdir -p $CURDIR/source_deb
    cp *.debian.tar.* $WORKDIR/source_deb
    cp *_source.changes $WORKDIR/source_deb
    cp *.dsc $WORKDIR/source_deb
    cp *.orig.tar.gz $WORKDIR/source_deb
    cp *.debian.tar.* $CURDIR/source_deb
    cp *_source.changes $CURDIR/source_deb
    cp *.dsc $CURDIR/source_deb
    cp *.orig.tar.gz $CURDIR/source_deb
}

build_deb(){
    if [ $DEB = 0 ]
    then
        echo "source deb package will not be created"
        return;
    fi
    if [ "x$OS" = "xrmp" ]
    then
        echo "It is not possible to build source deb here"
        exit 1
    fi
    #for file in 'dsc' 'orig.tar.gz' 'changes' 'debian.tar*'
    for file in 'dsc' 'orig.tar.gz' 'changes'
        do
        get_deb_sources $file
    done
    cd $WORKDIR
    rm -fv *.deb
    #
    export DEBIAN=$(lsb_release -sc)
    export ARCH=$(echo $(uname -m) | sed -e 's:i686:i386:g')
    #
    echo "DEBIAN=${DEBIAN}" >> percona-citus.properties
    echo "ARCH=${ARCH}" >> percona-citus.properties

    #
    DSC=$(basename $(find . -name '*.dsc' | sort | tail -n1))
    #
    dpkg-source -x ${DSC}
    #
    cd ${PRODUCT}-${VERSION}
    dch -m -D "${DEBIAN}" --force-distribution -v "1:${VERSION}-${DEB_RELEASE}.${DEBIAN}" 'Update distribution'
    unset $(locale|cut -d= -f1)
    dpkg-buildpackage -rfakeroot -us -uc -b
    mkdir -p $CURDIR/deb
    mkdir -p $WORKDIR/deb
    cp $WORKDIR/*.*deb $WORKDIR/deb
    cp $WORKDIR/*.*deb $CURDIR/deb
}
#main

CURDIR=$(pwd)
VERSION_FILE=$CURDIR/percona-citus.properties
args=
WORKDIR=
SRPM=0
SDEB=0
RPM=0
DEB=0
SOURCE=0
OS_NAME=
ARCH=
OS=
INSTALL=0
RPM_RELEASE=1
DEB_RELEASE=1
REVISION=0
BRANCH="v11.3.0"
REPO="https://github.com/citusdata/citus.git"
PRODUCT=percona-citus
DEBUG=0
parse_arguments PICK-ARGS-FROM-ARGV "$@"
VERSION='11.3.0'
RELEASE='1'
PRODUCT_FULL=${PRODUCT}-${VERSION}

check_workdir
get_system
install_deps
get_sources
build_srpm
build_source_deb
build_rpm
build_deb