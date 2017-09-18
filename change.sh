#!/bin/bash

for file in `ls|grep eos`;
do
oldname=$file
#newname=$(echo $file|sed 's#.cern##')
newname=$(echo $file|sed 's#eos#jes#')
echo $newname
mv $oldname $newname
done
