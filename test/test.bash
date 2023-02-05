#!/bin/bash

BAUD=300
DEV=/dev/ttyUSB0
#DEV=/dev/LOGAREX
stty -F $DEV $BAUD -parodd cs7 -cstopb parenb -ixoff -crtscts -hupcl -ixon -opost -onlcr -isig -icanon -iexten -echo -echoe -echoctl -echoke

echo -n -e '/?!\r\n' > $DEV

cat $DEV


