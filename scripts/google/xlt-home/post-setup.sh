#!/bin/bash
set -e

# remove unwanted packages
DEBIAN_FRONTEND=noninteractive apt-get -q -y purge \
  unattended-upgrades \
  google-cloud-cli
