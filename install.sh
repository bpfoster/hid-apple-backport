#!/bin/bash

set -e


MODULE_NAME="hid-apple2"
VERSION=3.10backport


KERNEL_MODULE_DIR="/usr/src/${MODULE_NAME}-${VERSION}/"

sudo mkdir -p ${KERNEL_MODULE_DIR}
sudo cp -r kernel/* ${KERNEL_MODULE_DIR}

pushd ${KERNEL_MODULE_DIR} > /dev/null

sed -i "s/{MODULE_NAME}/${MODULE_NAME}/; s/{MODULE_VERSION}/${VERSION}/" dkms.conf

sudo dkms add -m ${MODULE_NAME} -v ${VERSION}
sudo dkms build -m ${MODULE_NAME} -v ${VERSION}
sudo dkms install -m ${MODULE_NAME} -v ${VERSION}


popd > /dev/null

sudo cp modprobe/* /etc/modprobe.d/

sudo cp udev/* /etc/udev/rules.d/
