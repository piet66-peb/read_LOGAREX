#!/bin/bash
#h-------------------------------------------------------------------------------
#h
#h Name:         rrd_info.bash
#h Type:         Linux shell script
#h Purpose:      gets step and next time from rrb database
#h               and sets values NEXT and STEP
#h Project:      
#h Usage:        . `dirname $(readlink -f $0)`/rrd_info.bash
#h Result:       
#h Examples:     
#h Outline:      
#h Resources:    rrdtool, RRDTool_API
#h Platforms:    Linux
#h Authors:      peb piet66
#h Version:      V1.0.0 2023-01-25/peb
#v History:      V1.0.0 2022-12-09/peb first version
#h Copyright:    (C) piet66 2022
#h License:      MIT
#h
#h-------------------------------------------------------------------------------

MODULE='rrd_info.bash';
VERSION='V1.0.0'
WRITTEN='2023-01-25/peb'

if [ "$RRD_NAME" == "" ]
then    
    cd `dirname $0`
    . ./settings
fi

#get data from local database:
function get_rrd_info_local() {
    pushd $RRD_DIR >/dev/null
        echo ''
        C="rrdtool fetch $RRD_FILE LAST -s end-0"
        echo $C
        NEXT=`$C | grep ':' | cut -f1 -d:`
        echo NEXT=$NEXT

        echo ''
        C="rrdtool info $RRD_FILE"
        echo $C
        STEP=`$C | grep 'step' | cut -f3 -d' '`
        echo STEP=$STEP
    popd >/dev/null
}

#get data via RRDTool_API:
function get_rrd_info_remote() {
    URL="http://$IP:$PORT/$RRD_NAME/fetch?l=0&times=no"
    C="curl -sSN -o - -u ${USER_PW} ${URL}"
    echo ''
    echo "$C"
    response=`$C`

    ret=$?
    if [ $ret -ne 0 ]
    then
        echo $ret
        return
    fi

    echo $response
    ret=`echo $response | grep -c '\[\['`
    if [ $ret -eq 0 ]
    then
        return
    fi

    data=`echo $response | cut -f1 -d']'`
    STEP=`echo $data | cut -f3 -d','`
    NEXT=`echo $data | cut -f2 -d','`
    if [ "$STEP" != "" ]
    then
        echo STEP=$STEP
        echo NEXT=$NEXT
    fi
}

#main function:
function main() {
    if [ "$STORE_LOCAL_RBB" == true ]
    then    
        if [ -d "$RRD_DIR" ] && [ -e "$RRD_DIR/$RRD_FILE" ]
        then
            get_rrd_info_local
            if [ "$NEXT" == "" ]
            then
                echo error reading local database
                exit 1
            fi
        else
            echo defined local rrd database not found
            exit 1
        fi
    fi

    if [ "$STORE_REMOTE_RBB" == true ]
    then    
        while :
        do
            get_rrd_info_remote
            if [ "$NEXT" != "" ]
            then
                break
            fi
            echo error connecting remote database
            echo retrying after $REPEAT...
            sleep $REPEAT
        done
    fi
}

main
if [ "$STEP" == "" ] || [ "$NEXT" == "" ]
then
    echo STEP or NEXT empty, break.
    exit 1
fi

