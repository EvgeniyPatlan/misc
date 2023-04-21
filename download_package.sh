#!/usr/bin/env bash

shell_quote_string() {
  echo "$1" | sed -e 's,\([^a-zA-Z0-9/_.=-]\),\\\1,g'
}

usage () {
    cat <<EOF
Usage: $0 [OPTIONS]
    The following options may be given :
        --builddir=DIR      Absolute path to the dir where will store packages
        --get_packages      Source will be downloaded from github
        --install_deps      Install build dependencies(root privilages are required)
        --help) usage ;;
Example $0 --builddir=/tmp/BUILD --get_packages=<PACKAGE-NAME>
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
            --get_packages=*) SOURCE="$val" ;;
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


get_packages(){
    LASTDIR=$PWD
    cd "${WORKDIR}"
    if [ "${SOURCE}" = 0 ]
    then
        echo "Sources will not be downloaded"
        return 0
    fi

    if [ "x$OS" = "xrpm" ]; then
        yumdownloader --resolve --destdir $PWD/. ${SOURCE} 2>/dev/null
    else
        mkdir -p $PWD/archives/partial
        apt-get install -y -d -o=dir::cache=$PWD/. ${SOURCE} 2>/dev/null
        mv archives/*.deb ./
        rm -rf pkgcache.bin srcpkgcache.bin archives
    fi
    cd ${LASTDIR}
}

get_system(){
    if [ -f /etc/redhat-release ]; then
        OS="rpm"
    else
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
    CURPLACE=$(pwd)

    if [ "x$OS" = "xrpm" ]; then
        yum -y install yum-utils
    else
        export DEBIAN=$(lsb_release -sc)
        export ARCH=$(echo $(uname -m) | sed -e 's:i686:i386:g')
        until apt-get update; do
            sleep 1
            echo "waiting"
        done
        DEBIAN_FRONTEND=noninteractive apt install -y apt-rdepends
    fi
    return;
}



#main

if [ $( id -u ) -ne 0 ]
then
    echo "Please run as root"
    exit 1
fi

CURDIR=$(pwd)
args=
WORKDIR=
SOURCE=0
OS_NAME=
ARCH=
OS=
INSTALL=0
parse_arguments PICK-ARGS-FROM-ARGV "$@"

check_workdir
get_system
install_deps
get_packages
