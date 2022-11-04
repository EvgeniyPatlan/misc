#!/bin/bash

#script to run dev environment for percona products
#it is needed to install docker before this

if whiptail --yesno "Do you have Docker installed on your system" 0 0 ;then
    whiptail --msgbox "Great! Let's move to the next steps!" 0 0
    result=$(whiptail --title "Percona Products" --radiolist \
    "Choose Percona Product" 0 0 9 \
    "ps-8.0" "Percona Server for MySQL 8.0" ON \
    "ps-5.7" "Percona Server for MySQL 5.7" OFF \
    "pxc-8.0" "Percona XtraDB Cluster 8.0" OFF \
    "pxc-5.7" "Percona XtraDB Cluster 5.7" OFF \
    "pxb-8.0" "Percona XtraBackup 8.0" OFF \
    "psmdb-6.0" "Percona Server for MongoDB 6.0" OFF \
    "psmdb-5.0" "Percona Server for MongoDB 5.0" OFF \
    "psmdb-4.4" "Percona Server for MongoDB 4.4" OFF \
    "psmdb-4.2" "Percona Server for MongoDB 4.2" OFF 3>&2 2>&1 1>&3
    )
    product=$(echo $result | cut -d "-" -f 1)
    version=$(echo $result | cut -d "-" -f 2)

    if [ $product = "ps" ]; then
        product="percona-server"
        path="https://raw.githubusercontent.com/percona/$product/$version/build-ps/$product-"$version"_builder.sh"
    elif [ $product = "pxc" ]; then
        product="percona-xtradb-cluster"
        path="https://raw.githubusercontent.com/percona/$product/$version/build-ps/pxc_builder.sh"
    elif [ $product = "pxb" ]; then
        product="percona-xtrabackup"
        path="https://raw.githubusercontent.com/percona/$product/$version/storage/innobase/xtrabackup/utils/percona-xtrabackup-8.0_builder.sh"
    elif [ $product = "psmdb" ]; then
        path="https://raw.githubusercontent.com/percona/percona-server-mongodb/v$version/percona-packaging/scripts/psmdb_builder.sh"
        product="percona-server-mongodb"
    fi

    result=$(whiptail --title "Operation System" --radiolist \
    "Choose Supported OS" 0 0 9 \
    "centos-7" "Centos7" ON \
    "oel-8" "Centos8" OFF \
    "oel-9" "Centos8" OFF \
    "ubuntu-18.04" "Ubuntu Bionic" OFF \
    "ubuntu-20.04" "Ubuntu Focal" OFF \
    "ubuntu-22.04" "Ubuntu Jammy" OFF \
    "debian-10" "Debian Buster" OFF \
    "debian-11" "Debian Bullseye" OFF 3>&2 2>&1 1>&3
    )
    os_name=$(echo $result | cut -d "-" -f 1)
    os_version=$(echo $result | cut -d "-" -f 2)

    if [ $os_name = "oel" ]; then
        os_name="oraclelinux"
    fi

    echo "We need to run docker for $os_name $os_version to work on $product $version"
    name="$product-$version-$os_name-$os_version"
    docker run -it --rm -d --name=$name $os_name:$os_version
    container_id=$(docker ps -a | grep $name | awk '{print $1}')
    docker exec $container_id mkdir -p /tmp/test 
    docker exec $container_id curl -o /tmp/builder.sh $path 
    docker exec $container_id bash /tmp/builder.sh --builddir=/tmp/test --install_deps=1
    docker exec $container_id echo "You are inside DEV Environment"
    docker exec -it $container_id bash
else
    whiptail --msgbox "You need to install Docker!" 0 0
fi
