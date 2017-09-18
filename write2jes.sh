#!/bin/bash

if [ $# -lt 1 ];then
        echo "usage: $0 filesize"
	echo "$0 500M"
        exit 1
fi


if [ ! -d "/jes/data" ];then
	echo "jes mkdir /jes/data"
	jes mkdir /jes/data
	jes chmod 777 /jes/data
	#jes attr set default=raiddp /jes/data
fi

# start write

filename=$(date +%s)
filesize=$1

jesd=$(ps -ef|grep jesd|grep -v grep|wc -l)
if [ $jesd -eq 0 ];then
	service jesd start
fi

res=$(echo $filesize|grep M|wc -l)
if [ $res -eq "1" ];then
	echo "M Bytes"
	num=$(echo $filesize|grep -Eo '[0-9]+')
	dd if=/dev/zero of=/jes/data/tmp.$filename bs=1M count=$num
	exit
fi

res=$(echo $filesize|grep G|wc -l)
if [ $res -eq "1" ];then
	echo "G Bytes"
	num=$(echo $filesize|grep -Eo '[0-9]+')
	num=`expr $(($num*1000))`
	dd if=/dev/zero of=/jes/data/tmp.$filename bs=1M count=$num
	if [ $? -ne 0 ];then
		systemctl restart jes@*
		dd if=/dev/zero of=/jes/data/tmp.$filename bs=1M count=$num
	fi
	exit
fi

res=$(echo $filesize|grep T|wc -l)
if [ $res -eq "1" ];then
        echo "T Bytes"
        num=$(echo $filesize|grep -Eo '[0-9]+')
        num=`expr $(($num*1000*1000))`
        dd if=/dev/zero of=/jes/data/tmp.$filename bs=1M count=$num
        exit
fi

