#!/bin/bash
#h-------------------------------------------------------------------------------
#h
#h Name:         do_removes.bash
#h Type:         Linux shell script
#h Purpose:      do some removes
#h Project:      
#h Usage:        ./do_removes.bash
#h Result:       
#h Examples:     
#h Outline:      
#h Resources:    
#h Platforms:    Debian Linux (Raspberry Pi OS, Ubuntu)
#h Authors:      peb piet66
#h Version:      V1.0.0 2023-01-07/peb
#v History:      V1.0.0 2022-12-09/peb first version
#h Copyright:    (C) piet66 2022
#h License:      http://opensource.org/licenses/MIT
#h
#h-------------------------------------------------------------------------------

MODULE='do_removes.bash';
VERSION='V1.0.0'
WRITTEN='2023-01-07/peb'

#exit when any command fails
set -e

#set path constants
. `dirname $(readlink -f $0)`/00_constants

#remove cron
function cron_remove_line {
    l="$1"
    sudo crontab -l
    if [ $? -eq 0 ]
    then
        echo remove line if existing:
        X=`sudo crontab -l | sed "\:$l:d"`
        sudo crontab -r 
        echo "$X" | sudo crontab -
    fi
}

echo ''
echo removing cron-job for user $USER...
set +e
cron_remove_line "@reboot $PACKET_PATH/$PACKET_NAME.bash >/dev/null 2>&1"  >/dev/null 2>&1

