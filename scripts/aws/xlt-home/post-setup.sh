#!/bin/bash
set -e

# Update package index and install 'EC2 Instance Connect' package
DEBIAN_FRONTEND=noninteractive apt-get update && \
  apt-get --no-install-recommends -y install ec2-instance-connect

