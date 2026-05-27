#!/bin/sh

# shadowsocks script for AM380 merlin firmware
# by sadog (sadoneli@gmail.com) from koolshare.cn

eval `dbus export ss`
source /koolshare/scripts/base.sh
source helper.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'

get_mode_name() {
	case "$1" in
		1)
			echo "【gfwlist模式】"
		;;
		2)
			echo "【大陆白名单模式】"
		;;
		3)
			echo "【游戏模式】"
		;;
		5)
			echo "【全局模式】"
		;;
	esac
}

get_dns_name() {
	case "$1" in
		1)
			echo "cdns"
		;;
		2)
			echo "chinadns2"
		;;
		3)
			echo "dns2socks"
		;;
		4)
			if [ -n "$ss_basic_rss_obfs" ];then
				echo "ssr-tunnel"
			else
				echo "ss-tunnel"
			fi
		;;
		5)
			echo "chinadns1 + dns2socks上游"
		;;
		6)
			echo "https_dns_proxy"
		;;
		7)
			echo "v2ray dns"
		;;
		8)
			echo "koolgame内置"
		;;
		9)
			echo "SmartDNS"
		;;
		10)
			echo "ChinaDNS-NG"
		;;
	esac
}

get_action_chain() {
	case "$1" in
		0)
			echo "RETURN"
		;;
		1)
			echo "SHADOWSOCKS_GFW"
		;;
		2)
			echo "SHADOWSOCKS_CHN"
		;;
		3)
			echo "SHADOWSOCKS_GAM"
		;;
		5)
			echo "SHADOWSOCKS_GLO"
		;;
		6)
			echo "SHADOWSOCKS_HOM"
		;;
	esac
}

echo_version(){
	echo_date
	SOFVERSION=`cat /koolshare/ss/version`
	##---------------------------xray-----------------------
	if [ -z "$ss_basic_xray_version" ];then
		ss_basic_xray_version_tmp=`/koolshare/bin/xray -version 2>/dev/null | head -n 1 | cut -d " " -f2`
		if [ -n "$ss_basic_xray_version_tmp" ];then
			ss_basic_xray_version="$ss_basic_xray_version_tmp"
			dbus set ss_basic_xray_version="$ss_basic_xray_version_tmp"
		else
			ss_basic_xray_version="null"
		fi
	fi

	##---------------------------naive-----------------------
	if [ -z "$ss_basic_naive_version" ];then
		ss_basic_naive_version_tmp=`/koolshare/bin/naive -version 2>/dev/null | head -n 1 | cut -d " " -f2`
		if [ -n "$ss_basic_naive_version_tmp" ];then
			ss_basic_naive_version="$ss_basic_naive_version_tmp"
			dbus set ss_basic_naive_version="$ss_basic_naive_version_tmp"
		else
			ss_basic_naive_version="null"
		fi
	fi
	##---------------------------hysteria-----------------------
	if [ -z "$ss_basic_hysteria_version" ];then
		ss_basic_hysteria_version_tmp=`/koolshare/bin/hysteria version | grep 'Version:' | awk -F'[[:space:]]+' '{print $2}'`
		if [ -n "$ss_basic_hysteria_version_tmp" ];then
			ss_basic_hysteria_version="$ss_basic_hysteria_version_tmp"
			dbus set ss_basic_hysteria_version="$ss_basic_hysteria_version_tmp"
		else
			ss_basic_hysteria_version="null"
		fi
	fi

	##---------------------------anytls-----------------------
	if [ -z "$ss_basic_anytls_version" ];then
		ss_basic_anytls_version_tmp=`/koolshare/bin/anytls -version 2>/dev/null | head -n 1 | cut -d " " -f2`
		if [ -n "$ss_basic_anytls_version_tmp" ];then
			ss_basic_anytls_version="$ss_basic_anytls_version_tmp"
			dbus set ss_basic_anytls_version="$ss_basic_anytls_version_tmp"
		else
			ss_basic_anytls_version="null"
		fi
	fi

	echo ① 程序版本（插件版本：$SOFVERSION）：
	echo -----------------------------------------------------------
	echo "程序			版本		备注"
	echo "ss-redir		3.3.5		2020年9月15日编译"
	echo "ss-tunnel		3.3.5		2020年9月15日编译"
	echo "ss-local		3.3.5		2020年9月15日编译"
	echo "v2ray-plugin		4.45.0		2022年4月30日编译"
	echo "ssrr-redir		3.5.3 		2018年11月25日编译"
	echo "ssrr-tunnel		3.5.3 		2018年11月25日编译"
	echo "ssrr-local		3.5.3 		2018年11月25日编译"
	echo "haproxy			1.8.8 		2018年05月03日编译"
	echo "dns2socks		V2.0"
	echo "cdns			1.0 		2017年12月09日编译"
	echo "chinadns1		1.3.2 		2017年12月09日编译"
	echo "chinadns2		2.0.0 		2017年12月09日编译"
	echo "ChinaDNS-NG		1.0-beta.25 	2019年08月31日编译"
	echo "client_linux_arm5	20210922	kcptun"
	echo "xray			$ss_basic_xray_version	"	
	echo "naive		$ss_basic_naive_version	"
	echo "hysteria		$ss_basic_hysteria_version	"
	echo "anytls		$ss_basic_anytls_version	"
	echo -----------------------------------------------------------
}

check_status(){
	#echo
	SS_REDIR=`pidof ss-redir`
	SS_TUNNEL=`pidof ss-tunnel`
	SS_LOCAL=`ps|grep -w ss-local|grep 23456|awk '{print $1}'`
	V2RAY_PLUGIN=`pidof v2ray-plugin`
	OBFS_PLUGIN=`pidof obfs-local`
	SSR_REDIR=`pidof rss-redir`
	SSR_LOCAL=`ps|grep -w rss-local|grep 23456|awk '{print $1}'`
	SSR_TUNNEL=`pidof rss-tunnel`
	KOOLGAME=`pidof koolgame`
	DNS2SOCKS=`pidof dns2socks`
	CDNS=`pidof cdns`
	CHINADNS1=`pidof chinadns1`
	CHINADNS=`pidof chinadns`
	CHINADNSNG=`pidof chinadns-ng`
	KCPTUN=`pidof client_linux_arm5`
	HAPROXY=`pidof haproxy`
	V2RAY=`pidof v2ray`
	XRAY=`pidof xray`
	NAIVE=`pidof naive`
	HYSTERIA=`pidof hysteria`
	ANYTLS=`pidof anytls`
	HDP=`pidof https_dns_proxy`
	DMQ=`pidof dnsmasq`
	SMD=$(pidof smartdns)
	game_on=`dbus list ss_acl_mode|cut -d "=" -f 2 | grep 3`

	if [ "$ss_basic_type" == "0" ];then
		echo_version
		echo
		echo ② 检测当前相关进程工作状态：（你正在使用SS-libev,选择的模式是$(get_mode_name $ss_basic_mode),国外DNS解析方案是：$(get_dns_name $ss_foreign_dns)）
		echo -----------------------------------------------------------
		echo "程序		状态	PID"
		[ -n "$SS_REDIR" ] && echo "ss-redir	工作中	pid：$SS_REDIR" || echo "ss-redir	未运行"
		[ -n "$V2RAY_PLUGIN" ] && echo "v2ray-plugin	工作中	pid：$V2RAY_PLUGIN" || echo "v2ray-plugin	未运行"
		[ -n "$OBFS_PLUGIN" ] && echo "simple-obfs	工作中	pid：$OBFS_PLUGIN" || echo "simple-obfs	未运行"
	elif [ "$ss_basic_type" == "1" ];then
		echo_version
		echo
		echo ② 检测当前相关进程工作状态：（你正在使用SSR-libev,选择的模式是$(get_mode_name $ss_basic_mode),国外DNS解析方案是：$(get_dns_name $ss_foreign_dns)）
		echo -----------------------------------------------------------
		echo "程序		状态	PID"
		[ -n "$SSR_REDIR" ] && echo "ssr-redir	工作中	pid：$SSR_REDIR" || echo "ssr-redir	未运行"
	elif [ "$ss_basic_type" == "2" ];then
		echo_version
		echo
		echo ② 检测当前相关进程工作状态：（你正在使用koolgame,选择的模式是$(get_mode_name $ss_basic_mode),国外DNS解析方案是：$(get_dns_name 8)）
		echo -----------------------------------------------------------
		echo "程序		状态	PID"
		[ -n "$KOOLGAME" ] && echo "koolgame	工作中	pid：$KOOLGAME" || echo "koolgame	未运行"
	elif [ "$ss_basic_type" == "3" ];then
		echo_version
		echo
		echo ② 检测当前相关进程工作状态：（你正在使用V2Ray,选择的模式是$(get_mode_name $ss_basic_mode),国外DNS解析方案是：$(get_dns_name $ss_foreign_dns)）
		echo -----------------------------------------------------------
		echo "程序		状态	PID"
		[ -n "$V2RAY" ] && echo "v2ray		工作中	pid：$V2RAY" || echo "v2ray	未运行"
		[ -n "$XRAY" ] && echo "xray		工作中	pid：$XRAY" || echo "xray	未运行"
	elif [ "$ss_basic_type" == "4" ];then
		echo_version
		echo
		echo ② 检测当前相关进程工作状态：（你正在使用Trojan,选择的模式是$(get_mode_name $ss_basic_mode),国外DNS解析方案是：$(get_dns_name $ss_foreign_dns)）
		echo -----------------------------------------------------------
		echo "程序		状态	PID"
		[ -n "$XRAY" ] && echo "xray		工作中	pid：$XRAY" || echo "xray	未运行"	
		[ -n "$HYSTERIA" ] && echo "Hysteria2		工作中	pid：$HYSTERIA" || echo "Hysteria2	未运行"	
		[ -n "$ANYTLS" ] && echo "AnyTLS		工作中	pid：$ANYTLS" || echo "AnyTLS	未运行"
	elif [ "$ss_basic_type" == "5" ];then
		echo_version
		echo
		echo ② 检测当前相关进程工作状态：（你正在使用NaiveProxy,选择的模式是$(get_mode_name $ss_basic_mode),国外DNS解析方案是：$(get_dns_name $ss_foreign_dns)）
		echo -----------------------------------------------------------
		echo "程序		状态	PID"
		[ -n "$NAIVE" ] && echo "naiveproxy		工作中	pid：$NAIVE" || echo "naiveproxy	未运行"		
	fi

	if [ -z "$ss_basic_koolgame_udp" ];then
		if [ "$ss_basic_use_kcp" == "1" ];then
			[ -n "$KCPTUN" ] && echo "kcptun		工作中	pid：$KCPTUN" || echo "kcptun		未运行"
		fi
		
		if [ "$ss_basic_server" == "127.0.0.1" ];then
		 	[ -n "$HAPROXY" ] && echo "haproxy		工作中	pid：$HAPROXY" || echo "haproxy		未运行"
		fi
		
		if [ "$ss_foreign_dns" == "1" ];then
			[ -n "$CDNS" ] && echo "cdns		工作中	pid：$CDNS" || echo "cdns	未运行"
		elif [ "$ss_foreign_dns" == "2" ];then
			[ -n "$CHINADNS" ] && echo "chinadns	工作中	pid：$CHINADNS" || echo "chinadns	未运行"
		elif [ "$ss_foreign_dns" == "3" ];then
			if [ -n "$ss_basic_rss_obfs" ];then
				[ -n "$SSR_LOCAL" ] && echo "ssr-local	工作中	pid：$SSR_LOCAL" || echo "ssr-local	未运行"
				[ -n "$DNS2SOCKS" ] && echo "dns2socks	工作中	pid：$DNS2SOCKS" || echo "dns2socks	未运行"
			else
				if [ "$ss_basic_type" != "3" ];then
					[ -n "$SS_LOCAL" ] && echo "ss-local	工作中	pid：$SS_LOCAL" || echo "ss-local	未运行"
				fi
				[ -n "$DNS2SOCKS" ] && echo "dns2socks	工作中	pid：$DNS2SOCKS" || echo "dns2socks	未运行"
			fi
		elif [ "$ss_foreign_dns" == "4" ];then
			if [ -n "$ss_basic_rss_obfs" ];then
				[ -n "$SSR_TUNNEL" ] && echo "ssr-tunnel	工作中	pid：$SSR_TUNNEL" || echo "ssr-tunnel	未运行"
			else
				[ -n "$SS_TUNNEL" ] && echo "ss-tunnel	工作中	pid：$SS_TUNNEL" || echo "ss-tunnel	未运行"
			fi
		elif [ "$ss_foreign_dns" == "5" ];then
			if [ "$ss_basic_type" != "3" ];then
				[ -n "$SSR_LOCAL" ] && echo "ssr-local	工作中	pid：$SSR_LOCAL" || echo "ssr-local	未运行"
			fi
			[ -n "$DNS2SOCKS" ] && echo "dns2socks	工作中	pid：$DNS2SOCKS" || echo "dns2socks	未运行"
			[ -n "$CHINADNS1" ] && echo "chinadns1	工作中	pid：$CHINADNS1" || echo "chinadns1	未运行"
		elif [ "$ss_foreign_dns" == "6" ];then
			[ -n "$HDP" ] && echo "https_dns_proxy	工作中	pid：$HDP" || echo "https_dns_proxy	未运行"
		elif [ "$ss_foreign_dns" == "9" ]; then
			[ -n "$SMD" ] && echo "SmartDNS	工作中	pid：$SMD" || echo "SmartDNS	未运行"
		elif [ "$ss_foreign_dns" == "10" ]; then
			[ -n "$DNS2SOCKS" ] && echo "dns2socks	工作中	pid：$DNS2SOCKS" || echo "dns2socks	未运行"
			[ -n "$CHINADNSNG" ] && echo "ChinaDNS-NG	工作中	pid：$CHINADNSNG" || echo "ChinaDNS-NG	未运行"	
		fi
	fi
	[ "$ss_dnschina" == "13" ] &&{
		[ "$ss_foreign_dns" != "9" ] && [ -n "$SMD" ] && echo "SmartDNS	工作中	pid：$SMD" || echo "SmartDNS	未运行"
	}
	[ -n "$DMQ" ] && echo "dnsmasq		工作中	pid：$DMQ" || echo "dnsmasq	未运行"

	echo -----------------------------------------------------------
	echo
	echo
	echo ③ 检测iptbales工作状态：
	echo ----------------------------------------------------- nat表 PREROUTING 链 --------------------------------------------------------
	iptables -nvL PREROUTING -t nat
	echo
	echo ----------------------------------------------------- nat表 OUTPUT 链 ------------------------------------------------------------
	iptables -nvL OUTPUT -t nat
	echo
	echo ----------------------------------------------------- nat表 SHADOWSOCKS 链 --------------------------------------------------------
	iptables -nvL SHADOWSOCKS -t nat
	echo
	echo ----------------------------------------------------- nat表 SHADOWSOCKS_EXT 链 --------------------------------------------------------
	iptables -nvL SHADOWSOCKS_EXT -t nat
	echo
	echo ----------------------------------------------------- nat表 SHADOWSOCKS_GFW 链 ----------------------------------------------------
	iptables -nvL SHADOWSOCKS_GFW -t nat
	echo
	echo ----------------------------------------------------- nat表 SHADOWSOCKS_CHN 链 -----------------------------------------------------
	iptables -nvL SHADOWSOCKS_CHN -t nat
	echo
	echo ----------------------------------------------------- nat表 SHADOWSOCKS_GAM 链 -----------------------------------------------------
	iptables -nvL SHADOWSOCKS_GAM -t nat
	echo
	echo ----------------------------------------------------- nat表 SHADOWSOCKS_GLO 链 -----------------------------------------------------
	iptables -nvL SHADOWSOCKS_GLO -t nat
	echo
	echo ----------------------------------------------------- nat表 SHADOWSOCKS_HOM 链 -----------------------------------------------------
	iptables -nvL SHADOWSOCKS_HOM -t nat
	echo -----------------------------------------------------------------------------------------------------------------------------------
	echo
	[ -n "$game_on" ] || [ "$ss_basic_mode" == "3" ] || [ "$ss_basic_udp_sync" == "1" ] && echo ------------------------------------------------------ mangle表 PREROUTING 链 -------------------------------------------------------
	[ -n "$game_on" ] || [ "$ss_basic_mode" == "3" ] || [ "$ss_basic_udp_sync" == "1" ] && iptables -nvL PREROUTING -t mangle
	[ -n "$game_on" ] || [ "$ss_basic_mode" == "3" ] || [ "$ss_basic_udp_sync" == "1" ] && echo
	[ -n "$game_on" ] || [ "$ss_basic_mode" == "3" ] || [ "$ss_basic_udp_sync" == "1" ] && echo ------------------------------------------------------ mangle表 SHADOWSOCKS 链 -------------------------------------------------------
	[ -n "$game_on" ] || [ "$ss_basic_mode" == "3" ] || [ "$ss_basic_udp_sync" == "1" ] && iptables -nvL SHADOWSOCKS -t mangle
	[ -n "$game_on" ] || [ "$ss_basic_mode" == "3" ] || [ "$ss_basic_udp_sync" == "1" ] && echo
	[ -n "$game_on" ] || [ "$ss_basic_mode" == "3" ] || [ "$ss_basic_udp_sync" == "1" ] && echo ------------------------------------------------------ mangle表 $(get_action_chain $ss_basic_mode) 链 -------------------------------------------------------
	[ -n "$game_on" ] || [ "$ss_basic_mode" == "3" ] || [ "$ss_basic_udp_sync" == "1" ] && iptables -nvL $(get_action_chain $ss_basic_mode) -t mangle
	echo -----------------------------------------------------------------------------------------------------------------------------------
	echo
}

if [ "$ss_basic_enable" == "1" ];then
	echo "" > /tmp/ss_proc_status.log 2>&1
	check_status >> /tmp/ss_proc_status.log 2>&1
else
	echo 插件尚未启用！> /tmp/ss_proc_status.log 2>&1
fi
echo XU6J03M6 >> /tmp/ss_proc_status.log
