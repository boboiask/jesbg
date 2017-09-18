#!/usr/bin/env python
# -*- coding: utf-8 -*-
import subprocess
import re
import socket
import time
import sys
import struct
import logging
import commands

#监控磁盘组运行情况，当运行组空间到达阈值水位后，将剩余空间最小的磁盘移到冷盘组，并从待用组中选择一块磁盘加入到运行组中。

groups = ['default','cold','unused']
CONF = '/local/jesbg/server.conf'
echocmd="/opt/lampp/bin/php /home/huqb/deviceinfocollect_other2/diskoption.php"

logger = logging.getLogger('jes-bg')
logger.setLevel(logging.DEBUG)

fh = logging.FileHandler("/local/jesbg/jesserver.log")
fh.setLevel(logging.DEBUG)

formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')  
fh.setFormatter(formatter)
logger.addHandler(fh) 

info = logger.info
debug = logger.debug

# Get disk warning level
def parse_server_conf(conf):
    fd=open(conf, "r")
    diskWarnning = None
    for line in fd:
        line=line.strip()
        if line and not line.startswith("#"):
            (key,value)=line.split("=")
            key=key.strip()
            value=value.strip()
            if key.find("diskWarnning")>=0:
                diskWarnning=float(value)
    fd.close()
    return diskWarnning

# Get space info
def get_space_metrics(group):
    output = []
    p = subprocess.Popen(['jes', '-b', 'group', 'ls','%s'%group, '-m'],stdout=subprocess.PIPE)
    for line in p.stdout:
        print line
        matches = re.findall('([a-z][\w|.]*=[\w|:|.]+)\s+', line, re.MULTILINE)
        for match in matches:
            metric, value = match.split('=')
            if metric == 'sum.stat.statfs.usedbytes':
                usedSpace = re.match('\w+', value).group(0)
                print usedSpace
            if metric == 'sum.stat.statfs.capacity':
                capacity = re.match('\w+', value).group(0)
                print capacity
    usedPercent = round((float)((float)(usedSpace)/(float)(capacity))*100,2)
    return usedPercent

def get_group_name():
    output = []
    p = subprocess.Popen(['jes', '-b', 'group', 'ls', '-m'],stdout=subprocess.PIPE)
    for line in p.stdout:
        matches = re.findall('([a-z][\w|.]*=[\w|:|.]+)\s+', line, re.MULTILINE)
        space = None
        for match in matches:
            metric, value = match.split('=')
            if metric == 'name':
                space = re.match('\w+', value).group(0)
		output.append(space)
                #break
            #if metric in node_metrics:
            #    data = ('.'.join(['space', space, metric]), (int(time.time()), float(value)))
            #    output.append(data)
    return output

def get_running_fs(group):
    p = subprocess.Popen(['jes', '-b', 'fs', 'ls','%s'%group, '-m'],stdout=subprocess.PIPE)
    output = []
    idvalue = None
    uuid = None
    freebytes = None
    for line in p.stdout:
        matches = re.findall('([a-z][\w|.]*=[\w|.|/|-]+)\s+', line, re.MULTILINE)
        for match in matches:
            metric, value = match.split('=')
            if metric == 'id':
                idvalue=value
            elif metric == 'uuid':
                uuid=value
            elif metric == 'stat.statfs.freebytes':
                freebytes = value
            elif metric == 'path':
                path = value
        if idvalue and uuid and freebytes and path:
            output.append([idvalue,uuid,freebytes,path])
    output.sort(key=lambda x:x[2])
    return output


def get_unused_fs(group):
    p = subprocess.Popen(['jes', '-b', 'fs', 'ls','%s'%group, '-m'],stdout=subprocess.PIPE)
    output = []
    idvalue = None
    uuid = None
    for line in p.stdout:
        output = []
        matches = re.findall('([a-z][\w|.]*=[\w|.|/|-]+)\s+', line, re.MULTILINE)
        for match in matches:
            metric, value = match.split('=')
            if metric == 'id':
                idvalue=value
            elif metric == 'uuid':
                uuid=value
        if idvalue and uuid:
            output.append([idvalue,uuid])
    return output

def poweron(fsinfo):
    ok = None
    fsid = fsinfo[0]
    uuid = fsinfo[1]
    p = subprocess.Popen("%s -u %s -g unused -a poweron"%(echocmd,uuid), shell=True, stdout=subprocess.PIPE)
    p.wait()
    for line in p.stdout:
        print line
        if line == 'OK':
            info("ok, mv the fs to default")
            ok = True
            movefs2running(fsid,uuid)
            break
    if not ok:
        info("Error, please change another usused fs")
	return False
    return True

def movefs2running(fsid,uuid):
    #let the fsid poweron
    #check fs state, then mv to default
    p1 = subprocess.Popen(['jes', '-b', 'fs', 'mv','%s'%fsid, 'default.0'],stdout=subprocess.PIPE)
    p3 = subprocess.Popen("%s -u %s -g default -a poweron"%(echocmd,uuid), shell=True, stdout=subprocess.PIPE)
    p3.wait()
    #time.sleep(60)
    info("Begin to boot the fs, and set rw")
    p2 = subprocess.Popen(['jes', '-b', 'fs', 'boot','%s'%fsid],stdout=subprocess.PIPE)
    p = subprocess.Popen(['jes', '-b', 'fs', 'config','%s'%fsid, 'configstatus=rw'],stdout=subprocess.PIPE)
    #then move one old fs to cold

def movefs2cold(fsinfo):
    fsid = fsinfo[0]
    uuid = fsinfo[1]
    path = fsinfo[3]
    p = subprocess.Popen(['jes', '-b', 'fs', 'mv','%s'%fsid, 'cold.0'],stdout=subprocess.PIPE)
    
    datapath = path.split('/')[1]
    res,dev = commands.getstatusoutput('df |grep %s|cut -d" " -f1'%datapath)
    if dev:
        # set 150s to standby when no use
        p = subprocess.Popen("hdparm -S 30 %s"%dev, shell=True, stdout=subprocess.PIPE)
    p = subprocess.Popen("%s -u %s -g cold -a standby"%(echocmd,uuid), shell=True, stdout=subprocess.PIPE)

if __name__ == '__main__':
    diskwarning = parse_server_conf(CONF)
    res = get_space_metrics('default')
    #res *= 10
    info("The disk usage is %f"%res)
    info("The disk warning is %f"%float(diskwarning))

    if res > diskwarning:
        info("get warning")
        runlist=get_running_fs('default')
        #print "running:",runlist
        unusedlist=get_unused_fs('cold')
        info("select unused fs is %s"%unusedlist[0])
        for i in range(len(unusedlist)):
            info("select unused fs is %s"%unusedlist[i])
            result=poweron(unusedlist[i])
            if result:
                break 

        #info("select running fs is %s"%runlist[0])
        #time.sleep(60)
        info("select running fs is %s"%runlist[0])
        movefs2cold(runlist[0])

