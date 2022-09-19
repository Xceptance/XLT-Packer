#!/bin/bash
set -e

# manually install package ec2-instance-connect (not available in Debian package repo yet)
# TODO: the following fails in the moment
#dpkg -i $SCRIPT_DIR/ec2-instance-connect_1.1.14-0ubuntu1_all.deb

# remove unwanted packages
DEBIAN_FRONTEND=noninteractive apt-get -q -y purge \
  unattended-upgrades
