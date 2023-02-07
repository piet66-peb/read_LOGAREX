#!/bin/bash
#h-------------------------------------------------------------------------------
#h
#h Name:         read_LOGAREX.bash
#h Type:         Linux shell script
#h Purpose:      in an infinite loop:
#h                   reads value fom electric meter via infrared interface (optical
#h                   interface) and forwards it to a round-robin database and
#h                   additionally to a Z-Way virtual device 
#h
#h               it's made for LOGAREX electric meter LK13BD102015,
#h               year of manufacture: 2015
#h               parameters: 
#h                   300 baud, 7N1, no flow control, no handshake, pull mode,
#h                   no pin required
#h                   pull request: '/?!\r\n' = '\x2F\x3F\x21\x0D\x0A'
#h                   response data format: OBIS/EDIS protocol (ASCII text)
#h               data sent by electric meter after every pull request:
#h                   /LOG4LK13BD102015              #meter type
#h                   C.1.0(NNNNNNNN)                #meter id manufacturer
#h                   0.0.0(NNNNNNNNNNNNNN)          #meter id supplier
#h                   F.F(0000)                      #error code
#h                   1.8.0(035070.523*kWh)          #OBIS meter reading single tariff
#h                   C.7.1(00000002)                #count phase failure l1
#h                   C.7.2(00000001)                #                    l2
#h                   C.7.3(00000001)                #                    l3
#h                   0.2.1(ver.02, 130314, 41BD)    #versions
#h                   C.2.1(1412201128)              #event parameters change-timestamp
#h                   C.2.9(1412201128)              #last read
#h                   !
#h               remarks:
#h                   - LOGAREX has shipped the same meter type with different firmwares
#h                      ver.02, 130314, 41BD: needs 1 pull request
#h                      ver.02, 150228, 671A: needs a second pull request
#h                   - for testing of correct optohead position: the meter mirrors any ascii 
#h                     string.
#h               helpful links:
#h                   https://www.automaten-karl.de/?p=914
#h                   https://shop.weidmann-elektronik.de/media/files_public/9d73b590bf0752a5beff32d229d4497d/HowToRaspberryPi.pdf
#h                   http://www.weidmann-elektronik.de/Downloads.html
#h Installation: - detect the id of the serial device /dev/ttyUSBx of the IR reader:
#h                 ls /dev/ttyUSB*
#h                 >> plugin USB device
#h                 ls /dev/ttyUSB*
#h                 >> /dev/ttyUSB0
#h               - set logical name for the serial device /dev/LOGAREX:
#h                 get device serial:
#h                   udevadm info -a -n /dev/ttyUSB<n> | grep '{serial}' | head -n1
#h                   >> ATTRS{serial}=="0030"
#h                 enter in /etc/udev/rules.d/99-usb-serial.rules
#h                   SUBSYSTEM=="tty", ATTRS{serial}=="0030", SYMLINK+="LOGAREX", OWNER="pi"
#h                 or with {idVendor} and {idProduct}:
#h                   SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="LOGAREX"
#h                 sudo udevadm trigger (or sudo reboot)
#h                 ls -l /dev/LOGAREX
#h Project:      
#h Usage:        1. start manually:
#h                 cd <path>
#h                 ./read_LOGAREX.bash >/dev/null 2>&1 &
#h               2. run with cron:
#h                 crontab -e
#h                 and enter:
#h                   @reboot  <path>/read_LOGAREX.bash >/dev/null 2>&1
#h Result:       
#h Examples:     
#h Outline:      
#h Resources:    stty, curl, ./rrd_info.bash, ./store_rrd_local.bash, ./store_rrd_remote.bash, 
#h               ./store_zway.bash
#h Platforms:    Linux
#h Authors:      peb piet66
#h Version:      V2.0.0 2023-02-07/peb
#v History:      V1.0.0 2022-05-31/peb first version
#v               V1.3.0 2022-11-20/peb [+]STORE_COMMAND
#v               V2.0.0 2022-11-20/peb [*]some refactoring
#h Copyright:    (C) piet66 2022
#h License:      MIT
#h
#h-------------------------------------------------------------------------------

VERSION='V2.0.0'
WRITTEN='2023-02-07/peb'

cd `dirname $0`
SN=`basename $0`
LOG=$SN.log
date >$LOG

#b write start message to syslog
#-------------------------------
logger -i "$SN started."

#b take settings
#---------------
. ./settings >>$LOG 2>&1

if [ ! -c "$DEV" ]
then
    mess="serial input IR device $DEV not found, waiting..."
    logger -is "$SN $mess" >>$LOG 2>&1

    #wait 1 minute after boot till device is ready
    sleep 1m
    if [ ! -c "$DEV" ]
    then
        mess="serial input IR device $DEV not found, exit!"
        logger -is "$SN $mess" >>$LOG 2>&1
        exit 1
    fi
fi

#b read rrb parameters
#---------------------
. ./rrd_info.bash >>$LOG 2>&1

#serial interface
BAUD=300
PATTERN_180="1.8.0\(*\*kWh\)"   #line="1.8.0(035070.523*kWh)"
REQUEST_1='/?!'
REQUEST_2='\x06\x30\x30\x30'

#b functions
#-----------
function delay() {
    next=$1
    currtime=$(date +%s)             #current time in seconds
    #echo $currtime
    (( delay=next-currtime ));       # delay time in seconds
    echo $delay
}

function compute_rrd_time() {
    step=$STEP
    currtime=$(date +%s)             #current time in seconds
    (( rrd_time=(currtime/step)*step ));
    echo "   currtime=$currtime"
    echo "   rrd_time=$rrd_time"
}

#b commands
#----------
    #b serial interface parameters
    #-----------------------------
    # LOGAREX LK13BD102015: 300 baud, 7N1, no flow control, no handshake:
    #stty -F $DEV sane
    stty -F $DEV $BAUD -parodd cs7 -cstopb parenb -ixoff -crtscts -hupcl -ixon -opost -onlcr -isig -icanon -iexten -echo -echoe -echoctl -echoke
  
    #b trigger pull request in loop, synchronized with rrd database
    #--------------------------------------------------------------
    echo invoke pull loop
    next_run=$NEXT
    while true
    do
        sleep_next=`delay $next_run`
        echo ''
        echo --- sleeping $sleep_next seconds...
        sleep $sleep_next
        echo -n -e $REQUEST_1'\r\n' > $DEV
        last_run=$next_run
        (( next_run=last_run+STEP ));
    done &

    #b read in infinite loop
    #-----------------------
    echo listening to $DEV...
    #cat -A $DEV | while read line    # >> get also non-printing characters
    cat $DEV | while read line
               do
                  [  "$line" != "" ] && echo "$line"
                  case "$line" in 
                    # #b send second request
                    # #---------------------
                    # $REQUEST_1)
                    #     echo -n -e $REQUEST_2'\r\n' > $DEV
                    #     ;;

                    #b strip value for OBIS 1.8.0 and do storage
                    #-------------------------------------------
                    $PATTERN_180)
                        #parameter expansion:
                        ###a="${line#*\(}"      #remove first part till '('
                        ###value="${a%\**}"     #remove last part from '*' on
                        value=${line:6:-5}
                        VAL_Wh=${value/./}      #real >>> integer, kWh >>> Wh
                        compute_rrd_time

                        if [ "$STORE_LOCAL_RBB" == true ]
                        then
                            echo "   ./store_rrd_local.bash $rrd_time ${value}:$VAL_Wh"
                            ./store_rrd_local.bash $rrd_time ${value}:$VAL_Wh
                        fi

                        if [ "$STORE_REMOTE_RBB" == true ]
                        then
                            echo "   ./store_rrd_remote.bash $rrd_time ${value}:$VAL_Wh"
                            ./store_rrd_remote.bash $rrd_time ${value}:$VAL_Wh
                        fi

                        if [ "$STORE_ZWAY" == true ]
                        then
                            echo "   ./store_zway.bash $rrd_time ${value}"
                            ./store_zway.bash $rrd_time ${value}
                        fi

                        ;;
                  esac
               done
