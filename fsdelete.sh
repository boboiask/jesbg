#/bin/bash 

if [ $# -ne 2 ];then
	echo "usage: $0 startfsid endfsid"
fi

start=$1
stop=$2
for ((i=$1;i<=$2;i++)); do 
	jes fs config $i configstatus=empty;
	jes fs rm $i;
done
