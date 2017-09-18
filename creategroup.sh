#！/bin/sh


if [ $# -lt 1 ];then
	echo "usage : $0 groupname "dir1\;dir2""
	exit
fi

groupname=$1
dirlist=$2

echo "###add newgroup###"
jes space set $groupname on
if [ $? -ne 0 ];then
        echo "Error: failed to add group $groupname"
        exit 1
fi

jes space define $groupname 0 24

if [ -z "$dirlist" ];then
	exit
fi

i=1  
while((1==1))  
do  
        dir=`echo $dirlist|cut -d ";" -f$i`  
        if [ "$dir" != "" ]  
        then  
                ((i++))  
		if [ ! -d "$dir" ];then
       			echo "$dir is not exsit!"
       			break
		fi
		jes attr set sys.forced.group=$groupname $dir
		if [ $? -ne 0 ];then
			echo "Error: failed to set group for dir"
		fi
        else  
                break  
        fi  
done  
