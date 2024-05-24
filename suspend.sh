#!/bin/sh
#
# Copyright (C) 2024 uru (https://github.com/uru2)
# License is MIT (see LICENSE file)
set -eu

readonly NEXT_REC_START_MARGIN_SECOND=1200
readonly NEXT_REC_START_BEFORE_SECOND=120
readonly MIN_SLEEP_SECOND=600

export LANG=C.UTF-8

if [ ${NEXT_REC_START_MARGIN_SECOND} -lt ${NEXT_REC_START_BEFORE_SECOND} ]; then
  echo 'Initial setting error.' >&2
  exit 1
fi

# root check
if [ "$(whoami)" != 'root' ]; then
  echo 'Require root privilege' >&2
  exit 1
fi

# login user
if [ "$(w -h -s | wc -l)" -ge 1 ]; then
  # exists login user
  echo 'Logged in.'
  exit 0
fi

# .m2ts access
if lsof -F n | sed 's/^n\//\//g' | grep -q -E '\.m2ts$'; then
  # reading/writing .m2ts file
  echo 'Opened .m2ts files.'
  exit 0
fi

# tuner device
if lsof -F n | grep -q -E '^n/dev/(pt[13]video[0-9]+|asv5220[0-9]+|pxq3pe[0-9]+|pxw3u3[0-9]+|pxs3u[0-9]+|px[45]\-DTV[0-9]+|px4video[0-9]+|pxmlt[58]video[0-9]+|isdb2056video[0-9]+|isdb6014video[0-9]+|dvb/adapter[0-9]+)$'; then
  # using tuner device
  echo 'Tuner devices busy.'
  exit 0
fi

# running process
if pgrep ffmpeg; then
  # using ffmpeg
  echo 'Running ffmpeg command.'
  exit 0
fi

# sleep start unixtime-ms
target_rec_start_time=$(($(($(date +%s) + NEXT_REC_START_MARGIN_SECOND)) * 1000))

# epgstation recording
if [ "$(curl -s -X GET 'http://localhost:8888/api/recording?isHalfWidth=false' | tr -d '[:cntrl:]' | jq ".records | map(select(.endAt >= ${target_rec_start_time})) | length")" -ge 1 ]; then
  # recording
  echo 'Recording.'
  exit 0
fi

# epgstation next reserve
if [ "$(curl -s -X GET 'http://localhost:8888/api/reserves?isHalfWidth=true' | tr -d '[:cntrl:]' | jq '.reserves | length')" -eq 0 ]; then
  # reserve list empty, suspend now
  systemctl suspend
  exit 0
elif [ "$(curl -s -X GET 'http://localhost:8888/api/reserves?isHalfWidth=true' | tr -d '[:cntrl:]' | jq ".reserves | map(select(.isSkip == false and .startAt <= ${target_rec_start_time})) | length")" -ge 1 ]; then
  # exists reserve
  echo 'Reserve find.'
  exit 0
fi

# epgstation next reserve datetime
next_reserve_datetime=$(curl -s -X GET 'http://localhost:8888/api/reserves?isHalfWidth=true' | tr -d '[:cntrl:]' | jq -r '.reserves | map(select(.isSkip == false)) | sort_by(.startAt) | .[0] | .startAt')

# wakeup datetime
wakeup_unixtime=$(($((next_reserve_datetime - $((NEXT_REC_START_BEFORE_SECOND * 1000)))) / 1000))

# wakeup seconds
if [ "$((wakeup_unixtime - $(date +%s)))" -le "${MIN_SLEEP_SECOND}" ]; then
  # too short
  echo 'Too short sleep time.'
  exit 0
fi

# set wakeup datetime
echo "wakeup_datetime=$(date --date @${wakeup_unixtime})"
echo '0' > /sys/class/rtc/rtc0/wakealarm
echo "${wakeup_unixtime}" > /sys/class/rtc/rtc0/wakealarm

# system suspend
systemctl suspend
exit 0
