#! /bin/sh

# shadowsocks script for AM380 merlin firmware
# by sadog (sadoneli@gmail.com) from koolshare.cn

sh /koolshare/ss/ssconfig.sh stop
sh /koolshare/scripts/ss_conf_remove.sh
sleep 1

# 如果dnsmasq是mounted状态，先恢复
MOUNTED=`mount|grep -o dnsmasq`
if [ -n "$MOUNTED" ];then
	echo_date 恢复dnsmasq-fastlookup为原版dnsmasq
	killall dnsmasq >/dev/null 2>&1
	umount /usr/sbin/dnsmasq
	service restart_dnsmasq >/dev/null 2>&1
fi
TARGET_BIN="base64_encode cdns chinadns  chinadns1 chinadns-ng client_linux_arm5 dns2socks dnsmasq haproxy haveged hysteria anytls httping https_dns_proxy jq koolbox koolgame pdu resolveip rss-local rss-redir smartdns speederv1 speederv2 ss-local ss-redir ss-tunnel trojan-go naive udp2raw obfs-local xray"

rm -rf /koolshare/ss/*
rm -rf /koolshare/scripts/ss_*
rm -rf /koolshare/webs/Main_Ss*
cd /koolshare/bin && rm -f $TARGET_BIN && cd /tmp
rm -rf /koolshare/res/layer
rm -rf /koolshare/res/shadowsocks.css
rm -rf /koolshare/res/icon-shadowsocks.png
rm -rf /koolshare/res/ss-menu.js
rm -rf /koolshare/res/all.png
rm -rf /koolshare/res/gfwlist.png
rm -rf /koolshare/res/chn.png
rm -rf /koolshare/res/game.png
rm -rf /koolshare/res/shadowsocks.css
rm -rf /koolshare/res/gameV2.png
rm -rf /koolshare/res/ss_proc_status.htm
rm -rf /koolshare/init.d/S89Socks5.sh

# remove start up command
sed -i '/ssconfig.sh/d' /koolshare/scripts/wan-start >/dev/null 2>&1
sed -i '/ssconfig.sh/d' /koolshare/scripts/nat-start >/dev/null 2>&1

dbus remove softcenter_module_shadowsocks_home_url
dbus remove softcenter_module_shadowsocks_install
dbus remove softcenter_module_shadowsocks_md5
dbus remove softcenter_module_shadowsocks_version

dbus remove ss_basic_enable
dbus remove ss_basic_version_local
dbus remove ss_basic_version_web
