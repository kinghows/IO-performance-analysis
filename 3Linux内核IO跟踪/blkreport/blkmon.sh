#!/bin/bash

. /etc/profile

cd /root/monitor/blkreport/

blktrace -d /dev/dm-4 /dev/dm-5 /dev/dm-6 -w 10

blkparse -i dm-4 -d dm-4.bin > /dev/null

blkparse -i dm-5 -d dm-5.bin > /dev/null

blkparse -i dm-6 -d dm-6.bin > /dev/null

find . -name "*.blktrace.*" -exec rm -rf {} \;


