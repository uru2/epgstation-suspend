#!/bin/sh
#
# Copyright (C) 2024 uru (https://github.com/uru2)
# License is MIT (see LICENSE file)
set -eu

export LANG=C.UTF-8

# root check
if [ "$(whoami)" != 'root' ]; then
  echo 'Require root privilege' >&2
  exit 1
fi

# reset wakealarm
echo '0' > /sys/class/rtc/rtc0/wakealarm

# sync clock
chronyc makestep

# epgstation reset timer
curl -s -X POST 'http://localhost:8888/api/recording/resettimer'
exit 0
