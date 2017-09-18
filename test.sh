#!/bin/bash
LOGFILE=/tmp/testlog
echo_error(){
       echo "Error: "$(date "+%Y-%m-%d %H:%M:%S")" "$1 >> $LOGFILE     
}

#echo_error "testing"

DISKFILE="/local/jesbg/disk.conf"
LOGFILE="/local/jesbg/addfs.log"

defrundisk=$(cat $DISKFILE)
if [ -z "$defrundisk" ];then
        defrundisk=8
fi
echo $defrundisk
