#!/bin/sh

# shadowsocks script for AM380 merlin firmware
# by sadog (sadoneli@gmail.com) from koolshare.cn

eval `dbus export ss`
source /koolshare/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'

case $ss_binary_update in
2)
	core_bin="xray"
	;;
3)
	core_bin="naive"
	;;	
4)
	core_bin="hysteria"
	;;	
esac

get_bin_version() {
    if [ "$core_bin" = "hysteria" ]; then
        /koolshare/bin/hysteria version | grep 'Version:' | awk -F'[[:space:]]+' '{print $2}'| sed 's/v//g' 
    else
        ${core_bin} -version 2>/dev/null | head -n 1 | cut -d " " -f2 | sed 's/v//g' 
    fi
}

V2RAY_CONFIG_FILE="/koolshare/ss/v2ray.json"
NAIVE_CONFIG_FILE="/koolshare/ss/naive.json"
NAIVE2_CONFIG_FILE="/koolshare/ss/naive2.json"
HY2_CONFIG_FILE="/koolshare/ss/hysteria.json"

url_main="https://raw.githubusercontent.com/cary-sas/v2ray_bin/main/380_armv5/$core_bin"
url_back=""
socksopen_b=`netstat -nlp|grep -w 23456|grep -E "local|xray|naive|hysteria|anytls"`
if [ -n "$socksopen_b" ] && [ "$ss_basic_online_links_goss" == "1" ];then
	echo_date "代理有开启，将使用代理网络..."
	alias curlxx='curl --connect-timeout 8 -k --socks5-hostname 127.0.0.1:23456 '
else
	echo_date "使用常规网络下载..."
	alias curlxx='curl --connect-timeout 8 -k'
fi

get_latest_version(){
	[ -f "/tmp/${core_bin}_latest_info.txt"  ] && rm -rf /tmp/${core_bin}_latest_info.txt
	echo_date "检测${core_bin}最新版本..."
	curlxx $url_main/latest.txt > /tmp/${core_bin}_latest_info.txt
	if [ "$?" == "0" ];then
		if [ -z "`cat /tmp/${core_bin}_latest_info.txt`" ];then
			echo_date "获取${core_bin}最新版本信息失败！使用备用服务器检测！"
			get_latest_version_backup
		fi
		if [ -n "`cat /tmp/${core_bin}_latest_info.txt|grep "404"`" ];then
			echo_date "获取${core_bin}最新版本信息失败！使用备用服务器检测！"
			get_latest_version_backup
		fi
		V2VERSION=`cat /tmp/${core_bin}_latest_info.txt | sed 's/v//g'` || 0
		V2VERSION_BASE=${V2VERSION%-*}
		echo_date "检测到${core_bin}最新版本：v$V2VERSION_BASE"
		if [ ! -f "/koolshare/bin/${core_bin}"  ];then
			echo_date "${core_bin}安装文件丢失！重新下载！"
			CUR_VER="0"
		else
			CUR_VER=$(get_bin_version) || 0 
			echo_date "当前已安装${core_bin}版本：v$CUR_VER"
		fi
		COMP=`versioncmp $CUR_VER $V2VERSION_BASE`
		if [ "$COMP" == "1" ];then
			[ "$CUR_VER" != "0" ] && echo_date "${core_bin}已安装版本号低于最新版本，开始更新程序..."
			update_now v$V2VERSION
		else
			V2RAY_LOCAL_VER=$(get_bin_version)
			[ -n "$V2RAY_LOCAL_VER" ] && dbus set ss_basic_${core_bin}_version="$V2RAY_LOCAL_VER"
			echo_date "${core_bin}已安装版本已经是最新，退出更新程序!"
		fi
		[ -f "/tmp/${core_bin}" ] &&  rm -rf /tmp/${core_bin}
	else
		echo_date "获取${core_bin}最新版本信息失败！使用备用服务器检测！"
		get_latest_version_backup
	fi
	[ -f "/tmp/${core_bin}_latest_info.txt"  ] && rm -rf /tmp/${core_bin}_latest_info.txt
	dbus remove ss_binary_update
}

get_latest_version_backup(){
	echo_date "目前还没有任何备用服务器！"
	echo_date "获取${core_bin}最新版本信息失败！请检查到你的网络！"
	echo_date "==================================================================="
	echo XU6J03M6
	exit 1
}

update_now(){
	[ -f "/tmp/${core_bin}" ] && rm -rf /tmp/${core_bin}
	mkdir -p /tmp/${core_bin} && cd /tmp/${core_bin}

	echo_date "开始下载校验文件：md5sum.txt"
	curlxx  $url_main/$1/md5sum.txt > /tmp/${core_bin}/md5sum.txt
	if [ "$?" != "0" ];then
		echo_date "md5sum.txt下载失败！"
		md5sum_ok=0
	else
		md5sum_ok=1
		echo_date "md5sum.txt下载成功..."
	fi
	
	echo_date "开始下载${core_bin}程序"
	curlxx -o /tmp/${core_bin}/${core_bin} $url_main/$1/${core_bin}
	if [ "$?" != "0" ];then
		echo_date "${core_bin}下载失败！"
		v2ray_ok=0
	else
		v2ray_ok=1
		echo_date "${core_bin}程序下载成功..."
	fi

	if [ "$md5sum_ok" -eq 1 ] && [ "$v2ray_ok" -eq 1 ];then
		check_md5sum
	else
		echo_date "下载失败，请检查你的网络！"
		echo_date "==================================================================="
		echo XU6J03M6
		exit 1
	fi
}


check_md5sum(){
	cd /tmp/${core_bin}
	echo_date "校验下载的文件!"
	V2RAY_LOCAL_MD5=`md5sum ${core_bin}|awk '{print $1}'`
	V2RAY_ONLINE_MD5=`cat md5sum.txt|grep -w ${core_bin}|awk '{print $1}'`
	if [ "$V2RAY_LOCAL_MD5"x = "$V2RAY_ONLINE_MD5"x ];then
		echo_date "文件校验通过!"
		install_binary
	else
		echo_date "校验未通过，可能是下载过程出现了什么问题，请检查你的网络！"
		echo_date "==================================================================="
		echo XU6J03M6
		exit 1
	fi
}

install_binary(){
	echo_date "开始覆盖最新二进制!"
	if [ "`pidof ${core_bin}`" ];then
		echo_date "为了保证更新正确，先关闭${core_bin}主进程... "
		killall ${core_bin} >/dev/null 2>&1
		move_binary
		sleep 1
		start_v2ray
	else
		move_binary
	fi
}

move_binary(){
	echo_date "开始替换${core_bin}二进制文件... "
	mv /tmp/${core_bin}/${core_bin} /koolshare/bin/${core_bin}
	chmod +x /koolshare/bin/${core_bin}
	V2RAY_LOCAL_VER=$(get_bin_version)
	[ -n "$V2RAY_LOCAL_VER" ] && dbus set ss_basic_${core_bin}_version="$V2RAY_LOCAL_VER"
	echo_date "${core_bin}二进制文件替换成功... "
}

start_v2ray(){
	echo_date "开启${core_bin}进程... "
	cd /koolshare/bin
	export GOGC=30

	if [ "$core_bin" == "naive" ];then
		${core_bin} $NAIVE_CONFIG_FILE >/dev/null 2>&1 &
		${core_bin} $NAIVE2_CONFIG_FILE >/dev/null 2>&1 &
	elif [ "$core_bin" == "hysteria" ];then
		export QUIC_GO_DISABLE_ECN=true
		${core_bin} -c $HY2_CONFIG_FILE -l error --disable-update-check  >/dev/null 2>&1 &
	else
		${core_bin} --config=${V2RAY_CONFIG_FILE} >/dev/null 2>&1 &
	fi

	local i=10
	until [ -n "$V2PID" ]
	do
		i=$(($i-1))
		V2PID=`pidof ${core_bin}`
		if [ "$i" -lt 1 ];then
			echo_date "${core_bin}进程启动失败！"
			close_in_five
		fi
		sleep 1
	done
	echo_date ${core_bin}启动成功，pid：$V2PID
}

close_in_five(){
	echo_date "插件将在5秒后自动关闭！！"
	sleep 1
	echo_date 5
	sleep 1
	echo_date 4
	sleep 1
	echo_date 3
	sleep 1
	echo_date 2
	sleep 1
	echo_date 1
	sleep 1
	echo_date 0
	dbus set ss_basic_enable="0"
	#disable_ss >/dev/null
	#echo_date "插件已关闭！！"
	#echo_date ======================= 梅林固件 - 【科学上网】 ========================
	#unset_lock
	exit
}

echo_date "==================================================================="
echo_date "                ${core_bin}程序更新(Shell by sadog)"
echo_date "==================================================================="
get_latest_version
echo_date "==================================================================="
