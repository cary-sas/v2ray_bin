#!/bin/sh

v2ray_running_status=`ps | grep -w v2ray | grep -cv grep`
if [ "${v2ray_running_status}" -lt "1" ];then
    cd /koolshare/bin/
	  v2ray -config=/koolshare/ss/v2ray.json >> /tmp/auto_reload_v2ray.log 2>&1
fi
