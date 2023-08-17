#!/bin/bash

. /etc/profile

cd /root/monitor/blkreport/

python3 blkreport.py -d dm-4

python3 blkreport.py -d dm-5 

python3 blkreport.py -d dm-6

find . -regex '.*\.png\|.*\.result\|.*\.md'  -exec rm -rf {} \;




