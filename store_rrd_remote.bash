#!/bin/bash
#h-------------------------------------------------------------------------------
#h
#h Name:         store_rrd_remote.bash
#h Type:         Linux shell script
#h Purpose:      stores sensor value(s) to rrd database
#h Project:      
#h Usage:        ./store_rrd_remote.bash <timestamp> <colon separated value(s)> &
#h Result:       
#h Examples:     
#h Outline:      
#h Resources:    RRDTool_API
#h Platforms:    Linux
#h Authors:      peb piet66
#h Version:      V1.0.0 2023-01-18/peb
#v History:      V1.0.0 2022-12-09/peb first version
#h Copyright:    (C) piet66 2022
#h License:      MIT
#h
#h-------------------------------------------------------------------------------

MODULE='store_rrd_remote.bash';
VERSION='V1.0.0'
WRITTEN='2023-01-18/peb'

TS=$1
VALUE=$2

LOG="$0".log
date >$LOG
echo $0 $* >>$LOG
echo "TS: $TS VALUE: $VALUE" >>$LOG

if [ "$RRD_NAME" == "" ]
then    
    echo 'settings' >>$LOG
    . `dirname $0`/settings
fi

#send data to RRDTool_API:
function store_rrd_remote() {
    URL="http://$IP:$PORT/$RRD_NAME/update?ts=$TS&values=$VALUE"
    C="curl -sS -u ${USER_PW} -X POST ${URL}"     #POST
    echo ''
    echo $C
    $C
}

#main function:
function main() {
    if [ "$IP" != "" ]
    then    
        store_rrd_remote
    else
        echo no rrd settings defined
    fi
}

main >>$LOG 2>&1

