#!/bin/bash

# start XLT service (directly, not via 'service xlt start', so environment
# variables are available)
/etc/init.d/xlt start

# stop container from exiting
sleep infinity
