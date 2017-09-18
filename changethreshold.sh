#!/bin/bash

if [ $# -lt 2 ];then
	echo "usage: $0  groupname fslevel"
	printf "\tfor example: $0  default 80.00\n"
	exit 1
fi

file=/local/jesbg/server.conf
linenum=$(grep -n "diskWarnning" $file|cut  -d  ":"  -f  1)
echo $linenum
sed -i '2d' $file
echo "diskWarnning=$2" >> $file
