#!/bin/bash
# when boot the machine, add disk to unused group.
if [ $# -lt 2 ];then
	echo "usage: $0  uuid  path"
	printf "\tfor example: $0  uuid  /data01\n"
	exit 1
fi

uuid=$1
path=$2

hostname="coldstorage.ihep.ac.cn"
echocmd="/opt/lampp/bin/php /home/huqb/deviceinfocollect_other2/diskoption.php"
DISKFILE="/local/jesbg/disk.conf"
LOGFILE="/var/log/addfs.log"

defrundisk=$(cat $DISKFILE)
if [ -z "$defrundisk" ];then
        defrundisk=8
fi

#echo "###add $devname into jes "
#uuid=$(blkid $devname 2>/dev/null|awk '{print $2}'|cut -d"\"" -f2)
#if [ -z "$uuid" ];then
#	echo "Error: not found uuid for dev $devname"
#	exit 1
#fi
#path=$(mount -l|grep $devname|awk '{print $3}')
#if [ -z "$path" ];then
#        echo "Error: not found uuid for dev $devname"
#        exit 1
#fi

echo_info(){
	echo $(date "+%Y-%m-%d %H:%M:%S")" "$1 >> $LOGFILE
}

mkdir -p $path/jesd 2>/dev/null
chown daemon:daemon $path/jesd
if [ ! -d $path/jesd ];then
	echo_info "Error: failed create directory $path/jesd or it is a file" 
	exit 1
fi
mode=$(ls -ld /$path/jesd|awk '{print $3":"$4}')
if [ "$mode" != "daemon:daemon" ];then
	echo_info "Error: $path/jesd owner should be daemon:daemon"
fi

# select 5 dev into default group
defaultNum=$(jes fs ls default|grep $hostname|wc -l)
if [ $defaultNum -lt $defrundisk ];then
	echo_info "Info: add $uuid $hostname:1095 $path/jesd"
	res=$(jes fs add $uuid $hostname:1095 $path/jesd)
	if [ $? -ne 0 ];then
		echo_info "Error: failed to add fs for $uuid $path"
		exit 1
	fi
	fsid=$(echo $res | cut -d"=" -f3)
	jes fs config $fsid configstatus=rw
	jes fs boot $fsid
	# $echocmd -u uuid -g group -a action,group:"default,unused,cold",action:"poweron,poweroff,standby"
	echo_info "Info: fs $fsid add success: $uuid default poweron"
	$echocmd -u $uuid -g "default" -a "poweron"
	exit
	
fi

res=$(jes fs add $uuid $hostname:1095 $path/jesd unused 2>>$LOGFILE)
if [ $? -ne 0 ];then
	echo_info "Error: failed to add fs for $uuid $path"
	exit 1
fi
fsid=$(echo $res | cut -d"=" -f3)
jes fs config $fsid configstatus=rw
jes fs boot $fsid

num=0
while :
do
	status=$(jes fs status  $fsid|grep "stat.boot"|head -n 1|cut -d"=" -f2|cut -d" " -f2)
	if [ -z "$status" ];then
		sleep 2
		continue
	fi
	sleep 2
	echo $status
	if [ "$status" = "booted" ];then
		echo_info "Info: fs $fsid add success: $uuid unused poweroff"
	#	sleep 10
		umount $path
		#jes fs config $fsid configstatus=off
		$echocmd -u $uuid -g "unused" -a "poweroff" 
		break
	fi
        ((num++))
	echo $num
	if [[ $num -gt 10 ]];then
		break
	fi
done
