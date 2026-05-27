#!/bin/sh

##!/tmp/mnt/memory/entware/bin/bash -x
#export PS4='(${BASH_SOURCE}:${LINENO}): - [${SHLVL},${BASH_SUBSHELL},$?] $ '
# shadowsocks script for AM380 merlin firmware
# by sadog (sadoneli@gmail.com) from koolshare.cn

export KSROOT=/koolshare
source $KSROOT/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
eval `dbus export ss`
LOCK_FILE=/tmp/online_update.lock
CONFIG_FILE=/koolshare/ss/ss.json
DEL_SUBSCRIBE=0
SOCKS_FLAG=0

# ==============================
# ssconf_basic_webtest_
# ssconf_basic_node_
# ssconf_basic_koolgame_udp_
# ssconf_basic_method_
# ssconf_basic_mode_
# ssconf_basic_name_
# ssconf_basic_password_
# ssconf_basic_ss_v2ray_
# ssconf_basic_ss_kcp_support_
# ssconf_basic_ss_udp_support_
# ssconf_basic_ss_kcp_opts_
# ssconf_basic_ss_sskcp_server_
# ssconf_basic_ss_sskcp_port_
# ssconf_basic_ss_ssudp_server_
# ssconf_basic_ss_ssudp_port_
# ssconf_basic_ss_ssudp_mtu_
# ssconf_basic_ss_udp_opts_
# ssconf_basic_port_
# ssconf_basic_rss_obfs_
# ssconf_basic_rss_obfs_param_
# ssconf_basic_rss_protocol_
# ssconf_basic_rss_protocol_param_
# ssconf_basic_server_
# ssconf_basic_ss_v2ray_plugin_
# ssconf_basic_ss_v2ray_plugin_opts_
# ssconf_basic_use_kcp_
# ssconf_basic_use_lb_
# ssconf_basic_lbmode_
# ssconf_basic_weight_
# ssconf_basic_v2ray_use_json_
# ssconf_basic_v2ray_uuid_
# ssconf_basic_v2ray_alterid_
# ssconf_basic_v2ray_security_
# ssconf_basic_v2ray_network_
# ssconf_basic_v2ray_headtype_tcp_
# ssconf_basic_v2ray_headtype_kcp_
# ssconf_basic_v2ray_serviceName_
# ssconf_basic_v2ray_network_path_
# ssconf_basic_v2ray_network_host_
# ssconf_basic_v2ray_network_security_
# ssconf_basic_v2ray_mux_enable_
# ssconf_basic_v2ray_mux_concurrency_
# ssconf_basic_v2ray_json_
# ssconf_basic_v2ray_network_tlshost_
# ssconf_basic_v2ray_network_flow_
# ssconf_basic_type_
# ssconf_basic_v2ray_protocol_
# ssconf_basic_trojan_binary_
# ssconf_basic_trojan_network_
# ssconf_basic_trojan_sni_
# ssconf_basic_fingerprint_
# ssconf_basic_naive_protocol_
# ssconf_basic_naive_user_
# ssconf_basic_xray_publicKey_
# ssconf_basic_xray_shortId_
# ==============================

set_lock(){
	exec 233>"$LOCK_FILE"
	flock -n 233 || {
		echo_date "订阅脚本已经在运行，请稍候再试！"
		exit 1
	}
}

unset_lock(){
	flock -u 233
	rm -rf "$LOCK_FILE"
}

detect(){
	# 检测版本号
	firmware_version=`nvram get extendno|cut -d "X" -f2|cut -d "-" -f1|cut -d "_" -f1`
	if [ -f "/usr/bin/versioncmp" ];then
		firmware_comp=`versioncmp $firmware_version 7.7`
	else
		firmware_comp="1"
	fi
	
	if [ "$firmware_comp" == "0" -o "$firmware_comp" == "-1" ];then
		echo_date 检测到$firmware_version固件，支持订阅！
	else
		echo_date 订阅功能不支持X7.7以下的固件，当前固件版本$firmware_version，请更新固件！
		unset_lock
		exit 1
	fi
}

prepare(){
	# 0 检测排序
	seq_nu=`dbus list ssconf_basic_|grep _name_ | cut -d "=" -f1|cut -d "_" -f4|sort -n|wc -l`
	seq_max_nu=`dbus list ssconf_basic_|grep _name_ | cut -d "=" -f1|cut -d "_" -f4|sort -rn|head -n1`
	if [ "$seq_nu" == "$seq_max_nu" ];then
		echo_date "节点顺序正确，无需调整!"
		return 0
	fi 
	# 1 提取干净的节点配置，并重新排序
	echo_date 备份shadowsocks节点信息...
	echo_date 如果节点数量过多，此处可能需要等待较长时间，请耐心等待...
	rm -rf /tmp/ss_conf.sh
	touch /tmp/ss_conf.sh
	chmod +x /tmp/ss_conf.sh
	echo "#!/bin/sh" >> /tmp/ss_conf.sh
	valid_nus=`dbus list ssconf_basic_|grep _name_ | cut -d "=" -f1|cut -d "_" -f4|sort -n`
	q=1
	for nu in $valid_nus
	do
		[[ $nu -gt 1000 ]] && group_index_node=$((nu/1000*1000))
		[[ $nu -gt 1000 ]] && [[ $nu -gt $group_index_node ]] && [[ $q -lt $group_index_node ]]  && q=$((q%1000+group_index_node))
		[ -n "$(dbus get ssconf_basic_koolgame_udp_$nu)" ] && echo dbus set ssconf_basic_koolgame_udp_$q=$(dbus get ssconf_basic_koolgame_udp_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_method_$nu)" ] && echo dbus set ssconf_basic_method_$q=$(dbus get ssconf_basic_method_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_mode_$nu)" ] && echo dbus set ssconf_basic_mode_$q=$(dbus get ssconf_basic_mode_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_name_$nu)" ] && echo dbus set ssconf_basic_name_$q=$(dbus get ssconf_basic_name_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_password_$nu)" ] && echo dbus set ssconf_basic_password_$q=$(dbus get ssconf_basic_password_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_port_$nu)" ] && echo dbus set ssconf_basic_port_$q=$(dbus get ssconf_basic_port_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_v2ray_$nu)" ] && echo dbus set ssconf_basic_ss_v2ray_$q=$(dbus get ssconf_basic_ss_v2ray_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_kcp_support_$nu)" ] && echo dbus set ssconf_basic_ss_kcp_support_$q=$(dbus get ssconf_basic_ss_kcp_support_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_udp_support_$nu)" ] && echo dbus set ssconf_basic_ss_udp_support_$q=$(dbus get ssconf_basic_ss_udp_support_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_kcp_opts_$nu)" ] && echo dbus set ssconf_basic_ss_kcp_opts_$q=$(dbus get ssconf_basic_ss_kcp_opts_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_sskcp_server_$nu)" ] && echo dbus set ssconf_basic_ss_sskcp_server_$q=$(dbus get ssconf_basic_ss_sskcp_server_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_sskcp_port_$nu)" ] && echo dbus set ssconf_basic_ss_sskcp_port_$q=$(dbus get ssconf_basic_ss_sskcp_port_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_ssudp_server_$nu)" ] && echo dbus set ssconf_basic_ss_ssudp_server_$q=$(dbus get ssconf_basic_ss_ssudp_server_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_ssudp_port_$nu)" ] && echo dbus set ssconf_basic_ss_ssudp_port_$q=$(dbus get ssconf_basic_ss_ssudp_port_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_ssudp_mtu_$nu)" ] && echo dbus set ssconf_basic_ss_ssudp_mtu_$q=$(dbus get ssconf_basic_ss_ssudp_mtu_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_udp_opts_$nu)" ] && echo dbus set ssconf_basic_ss_udp_opts_$q=$(dbus get ssconf_basic_ss_udp_opts_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_rss_obfs_$nu)" ] && echo dbus set ssconf_basic_rss_obfs_$q=$(dbus get ssconf_basic_rss_obfs_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_rss_obfs_param_$nu)" ] && echo dbus set ssconf_basic_rss_obfs_param_$q=$(dbus get ssconf_basic_rss_obfs_param_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_rss_protocol_$nu)" ] && echo dbus set ssconf_basic_rss_protocol_$q=$(dbus get ssconf_basic_rss_protocol_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_rss_protocol_param_$nu)" ] && echo dbus set ssconf_basic_rss_protocol_param_$q=$(dbus get ssconf_basic_rss_protocol_param_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_server_$nu)" ] && echo dbus set ssconf_basic_server_$q=$(dbus get ssconf_basic_server_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_v2ray_plugin_$nu)" ] && echo dbus set ssconf_basic_ss_v2ray_plugin_$q=$(dbus get ssconf_basic_ss_v2ray_plugin_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_ss_v2ray_plugin_opts_$nu)" ] && echo dbus set ssconf_basic_ss_v2ray_plugin_opts_$q=$(dbus get ssconf_basic_ss_v2ray_plugin_opts_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_use_kcp_$nu)" ] && echo dbus set ssconf_basic_use_kcp_$q=$(dbus get ssconf_basic_use_kcp_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_use_lb_$nu)" ] && echo dbus set ssconf_basic_use_lb_$q=$(dbus get ssconf_basic_use_lb_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_lbmode_$nu)" ] && echo dbus set ssconf_basic_lbmode_$q=$(dbus get ssconf_basic_lbmode_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_weight_$nu)" ] && echo dbus set ssconf_basic_weight_$q=$(dbus get ssconf_basic_weight_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_group_$nu)" ] && echo dbus set ssconf_basic_group_$q=$(dbus get ssconf_basic_group_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_use_json_$nu)" ] && echo dbus set ssconf_basic_v2ray_use_json_$q=$(dbus get ssconf_basic_v2ray_use_json_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_uuid_$nu)" ] && echo dbus set ssconf_basic_v2ray_uuid_$q=$(dbus get ssconf_basic_v2ray_uuid_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_alterid_$nu)" ] && echo dbus set ssconf_basic_v2ray_alterid_$q=$(dbus get ssconf_basic_v2ray_alterid_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_security_$nu)" ] && echo dbus set ssconf_basic_v2ray_security_$q=$(dbus get ssconf_basic_v2ray_security_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_network_$nu)" ] && echo dbus set ssconf_basic_v2ray_network_$q=$(dbus get ssconf_basic_v2ray_network_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_headtype_tcp_$nu)" ] && echo dbus set ssconf_basic_v2ray_headtype_tcp_$q=$(dbus get ssconf_basic_v2ray_headtype_tcp_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_serviceName_$nu)" ] && echo dbus set ssconf_basic_v2ray_serviceName_$q=$(dbus get ssconf_basic_v2ray_serviceName_$nu) >> /tmp/ss_conf.sh		
		[ -n "$(dbus get ssconf_basic_v2ray_headtype_kcp_$nu)" ] && echo dbus set ssconf_basic_v2ray_headtype_kcp_$q=$(dbus get ssconf_basic_v2ray_headtype_kcp_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_network_path_$nu)" ] && echo dbus set ssconf_basic_v2ray_network_path_$q=$(dbus get ssconf_basic_v2ray_network_path_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_network_host_$nu)" ] && echo dbus set ssconf_basic_v2ray_network_host_$q=$(dbus get ssconf_basic_v2ray_network_host_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_network_security_$nu)" ] && echo dbus set ssconf_basic_v2ray_network_security_$q=$(dbus get ssconf_basic_v2ray_network_security_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_allowinsecure_$nu)" ] && echo dbus set ssconf_basic_allowinsecure_$q=$(dbus get ssconf_basic_allowinsecure_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_mux_enable_$nu)" ] && echo dbus set ssconf_basic_v2ray_mux_enable_$q=$(dbus get ssconf_basic_v2ray_mux_enable_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_mux_concurrency_$nu)" ] && echo dbus set ssconf_basic_v2ray_mux_concurrency_$q=$(dbus get ssconf_basic_v2ray_mux_concurrency_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_json_$nu)" ] && echo dbus set ssconf_basic_v2ray_json_$q=$(dbus get ssconf_basic_v2ray_json_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_trojan_binary_$nu)" ] && echo dbus set ssconf_basic_trojan_binary_$q=$(dbus get ssconf_basic_trojan_binary_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_trojan_network_$nu)" ] && echo dbus set ssconf_basic_trojan_network_$q=$(dbus get ssconf_basic_trojan_network_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_trojan_sni_$nu)" ] && echo dbus set ssconf_basic_trojan_sni_$q=$(dbus get ssconf_basic_trojan_sni_$nu)  >> /tmp/ss_conf.sh	
		[ -n "$(dbus get ssconf_basic_type_$nu)" ] && echo dbus set ssconf_basic_type_$q=$(dbus get ssconf_basic_type_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_protocol_$nu)" ] && echo dbus set ssconf_basic_v2ray_protocol_$q=$(dbus get ssconf_basic_v2ray_protocol_$nu) >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_v2ray_network_tlshost_$nu)" ] && echo dbus set ssconf_basic_v2ray_network_tlshost_$q=$(dbus get ssconf_basic_v2ray_network_tlshost_$nu)  >> /tmp/ss_conf.sh	
		[ -n "$(dbus get ssconf_basic_v2ray_network_flow_$nu)" ] && echo dbus set ssconf_basic_v2ray_network_flow_$q=$(dbus get ssconf_basic_v2ray_network_flow_$nu)  >> /tmp/ss_conf.sh	
		[ -n "$(dbus get ssconf_basic_fingerprint_$nu)" ] && echo dbus set ssconf_basic_fingerprint_$q=$(dbus get ssconf_basic_fingerprint_$nu)  >> /tmp/ss_conf.sh			
		[ -n "$(dbus get ssconf_basic_naive_protocol_$nu)" ] && echo dbus set ssconf_basic_naive_protocol_$q=$(dbus get ssconf_basic_naive_protocol_$nu)  >> /tmp/ss_conf.sh	
		[ -n "$(dbus get ssconf_basic_naive_user_$nu)" ] && echo dbus set ssconf_basic_naive_user_$q=$(dbus get ssconf_basic_naive_user_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_xray_publicKey_$nu)" ] && echo dbus set ssconf_basic_xray_publicKey_$q=$(dbus get ssconf_basic_xray_publicKey_$nu)  >> /tmp/ss_conf.sh
		[ -n "$(dbus get ssconf_basic_xray_shortId_$nu)" ] && echo dbus set ssconf_basic_xray_shortId_$q=$(dbus get ssconf_basic_xray_shortId_$nu)  >> /tmp/ss_conf.sh

		echo "#------------------------" >> /tmp/ss_conf.sh
		if [ "$nu" == "$ssconf_basic_node" ];then
			echo dbus set ssconf_basic_node=$q >> /tmp/ss_conf.sh
		fi
		let q+=1
	done
	#echo $q
	# -----------------
	# 2 清除已有的ss节点配置
	echo_date 一些必要的检查工作...
	confs=`dbus list ssconf_basic_ | cut -d "=" -f 1`
	for conf in $confs
	do
		#echo_date 移除$conf
		dbus remove $conf
	done
	# -----------------
	# 3 应用之前提取的干净的ss配置
	echo_date 检查完毕！节点信息备份在/koolshare/configs/ss_conf.sh
	</tmp/ss_conf.sh sed -e 's/=/=\"/' -e 's/$/\"/g' > /koolshare/configs/ss_conf.sh
	sh /koolshare/configs/ss_conf.sh
	# ==============================
}


base64decode_link(){
	local link=$1
	local len=`echo $link| wc -L`
	local mod4=$(($len%4))
	if [ "$mod4" -gt "0" ]; then
		local var="===="
		local newlink=${link}${var:$mod4}
		echo -n "$newlink" | sed 's/-/+/g; s/_/\//g' | base64 -d 2>/dev/null
	else
		echo -n "$link" | sed 's/-/+/g; s/_/\//g' | base64 -d 2>/dev/null
	fi
}

# 有些链接被 url 编码过，所以要先 url 解码
#urldecode(){ : "${*//+/ }"; echo -e "${_//%/\\x}"; }
urldecode(){
	printf '%b\n' "$(sed 's/\\/\\\\/g;s/\(%\)\([0-9a-fA-F][0-9a-fA-F]\)/\\x\2/g')"
}

dbus_update_if_diff() {
  local _key="$1"
  local _val="$2"
  local _old

  _old="$(dbus get "$_key")"

  # 相同：不更新，返回 1（让调用处 && 不触发）
  [ "$_old" = "$_val" ] && return 1

  dbus set "${_key}=${_val}"
  return 0
}

##################################################################################################
# ss 节点添加解析并更新
##################################################################################################
add_ss_servers(){
	[[ $1 -ge 1000 ]] &&  local group_index=$1
	ssindex_x=$(($(dbus list ssconf_basic_|grep _name_ |awk -v group_index=$((group_index+1000)) -F'[_=]' '{if($4<group_index)print$4}' |sort -rn|head -n1)+1))
	[[ $ssindex_x -gt 1000 ]] && ssindex_x=$((ssindex_x%1000))
	ssindex=$((ssindex_x+group_index))
#	echo_date "添加 ss 节点：$remarks"
	[[ $1 -ge 1000 ]] && dbus set ssconf_basic_group_$ssindex=$group
	dbus set ssconf_basic_name_$ssindex=$remarks
	dbus set ssconf_basic_mode_$ssindex=$ssr_subscribe_mode
	dbus set ssconf_basic_server_$ssindex=$server
	dbus set ssconf_basic_port_$ssindex=$server_port
	dbus set ssconf_basic_method_$ssindex=$encrypt_method
	dbus set ssconf_basic_password_$ssindex=$password
	dbus set ssconf_basic_type_$ssindex="0"
	dbus set ssconf_basic_ss_v2ray_$ssindex=$ss_v2ray_tmp
	dbus set ssconf_basic_ss_v2ray_plugin_$ssindex=$ss_v2ray_plugin_tmp
	dbus set ssconf_basic_ss_v2ray_plugin_opts_$ssindex=$ss_v2ray_opts_tmp
	dbus set ssconf_basic_ss_kcp_support_$ssindex=$ss_kcp_support_tmp
	dbus set ssconf_basic_ss_udp_support_$ssindex=$ss_udp_support_tmp
	dbus set ssconf_basic_ss_kcp_opts_$ssindex=$ss_kcp_opts_tmp
	dbus set ssconf_basic_ss_sskcp_server_$ssindex=$ss_sskcp_server_tmp
	dbus set ssconf_basic_ss_sskcp_port_$ssindex=$ss_sskcp_port_tmp
	dbus set ssconf_basic_ss_ssudp_server_$ssindex=$ss_ssudp_server_tmp
	dbus set ssconf_basic_ss_ssudp_port_$ssindex=$ss_ssudp_port_tmp
	dbus set ssconf_basic_ss_ssudp_mtu_$ssindex=$ss_ssudp_mtu_tmp
	dbus set ssconf_basic_ss_udp_opts_$ssindex=$ss_udp_opts_tmp

	echo_date "SS节点：新增加【$remarks】到节点列表第 $ssindex_x 位。"

	#初始化
	encrypt_method=""
	ss_v2ray_tmp="0"
	ss_v2ray_plugin_tmp="0"
	ss_v2ray_opts_tmp=""
	ss_kcp_support_tmp="0"
	ss_udp_support_tmp="0"
	ss_kcp_opts_tmp=""
	ss_sskcp_server_tmp=""
	ss_sskcp_port_tmp=""
	ss_ssudp_server_tmp=""
	ss_ssudp_port_tmp=""
	ss_ssudp_mtu_tmp=""
	ss_udp_opts_tmp=""
}

get_ss_config(){
	decode_link="$1"
	if [ -z "$decode_link" ];then
		echo_date "解析失败！！！"
		return 1
	fi

	group="$2"

	if [ -n "$(echo -n "$decode_link" | grep '#')" ];then
		remarks=$(echo -n $decode_link | awk -F'#' '{print $2}' | sed 's/[\r\n ]//g' ) # 因为订阅的 ss 里面有 \r\n ，所以需要先去除，否则就炸了，只能卸载重装				
	else
		remarks="$remarks" 
	fi
	
#   aes-256-gcm:kD9vkjnE6dsUzwQfvKkPkQAd@185.242.4.163:37588

   if [ -n "$(echo -n "$decode_link" | awk -F'#' '{print $1}' | grep '@')" ];then
		paraminfo=$(base64decode_link `echo -n "$decode_link" | awk -F'@' '{print $1}'`)
		server=$(echo "$decode_link" |awk -F'[@?#]' '{print $2}'| awk -F':' '{print $1}')
		server_port=$(echo "$decode_link" |awk -F'[@?#]' '{print $2}'| awk -F'[:/]' '{print $2}')
		encrypt_method="${paraminfo%%:*}"
		password="${paraminfo#*:}"
		password=$(echo "$password" | base64_encode)
   else  
   		#	ss://YWVzLTI1Ni1nY206THh6ZkFWZktiUHFReDRTRENhdDdFSnlFQDg0LjE3LjM0LjQ0OjQ3NjQ0#Japan 4 🇯🇵 (t.me/SurfShark_ALA)
		#   aes-256-gcm:LxzfAVfKbPqQx4SDCat7EJyE@84.17.34.44:47644#Japan 4 🇯🇵 (t.me/SurfShark_ALA)
		paraminfo=$(base64decode_link `echo -n "$decode_link" | awk -F'#' '{print $1}'`)
		server=$(echo "$paraminfo" |awk -F'[@:?]' '{print $3}')
		server_port=$(echo "$paraminfo" |awk -F'[:@/?]' '{print $4}')
	#   首段的加密方式跟密码进行解码，method_password=aes-128-gcm:VXPipi29nxMO
	#	method_password=$(echo "$decode_link" |awk -F'[@:]' '{print $1}' | sed 's/-/+/g; s/_/\//g')
	#	method_password=$(base64decode_link $(echo "$method_password"))
		encrypt_method="${paraminfo%%:*}"
		password="${paraminfo#*:}"
		password="${password%%@*}"
		password=$(echo "$password" | base64_encode)
	fi	
	
	#v2ray plugin : simple obfs will not be supported anymore, v2ray plugin will replace it
	# link format example
	# plugin=v2ray;path=/s233;host=yes.herokuapp.com;tls
	# plugin=V2ray-plugin;path=/s233;host=yes.herokuapp.com;tls#nodename4test

	#simple-obfs : Deprecated. Followed by v2ray-plugin.
    # plugin=simple-obfs;obfs=http;obfs-host=www.bing.com

	#	初始化
	ss_v2ray_tmp="0"
	ss_v2ray_plugin_tmp="0"	
	ss_kcp_support_tmp="0"
	ss_udp_support_tmp="0"


	if [ -n "$(echo -n "$decode_link" | grep "?")" ];then
		plugin=$(echo "$decode_link" |awk -F'[?#]' '{print $2}')
		plugin_type=$(echo "$plugin" | tr ';' '\n' | grep 'plugin=' | awk -F'=' '{print $2}' | tr '[A-Z]' '[a-z]')	
		ss_kcp_support_tmp="0"
		ss_udp_support_tmp="0"
		ss_kcp_opts_tmp=""
		ss_sskcp_server_tmp=""
		ss_sskcp_port_tmp=""
		ss_ssudp_server_tmp=""
		ss_ssudp_port_tmp=""
		ss_ssudp_mtu_tmp=""
		ss_udp_opts_tmp=""

		if [ -n "$plugin" ] && [ -z "${plugin_type##*v2ray*}" ] && [ -n "$plugin_type" ];then
			ss_v2ray_tmp="1"
			ss_v2ray_opts_tmp="$(echo $plugin | cut -d";" -f2-)"
			ss_v2ray_plugin_tmp="1"
		elif [ -n "$plugin" ] && [ -z "${plugin_type##*obfs*}" ] && [ -n "$plugin_type" ];then
			ss_v2ray_tmp="2"
			ss_v2ray_opts_tmp="$(echo $plugin | cut -d";" -f2-)"
			ss_v2ray_plugin_tmp="2"					
		else 
			ss_v2ray_tmp="0"
			ss_v2ray_opts_tmp=""
			ss_v2ray_plugin_tmp="0"	
		fi
	fi

	[ -n "$group" ] && group_base64=`echo $group | base64_encode | sed 's/ -//g'`
	[ -n "$server" ] && server_base64=`echo $server | base64_encode | sed 's/ -//g'`
	[ -n "$remarks" ] && remarks_base64=`echo $remarks | base64_encode | sed 's/ -//g'`

	[ -n "$node_regexp" ] && incNY=`echo $remarks $server  | sed -n "$node_regexp"` || incNY="Y"

	#把全部服务器节点写入文件 /usr/share/shadowsocks/serverconfig/all_onlineservers
	[ -n "$incNY" ] && [ -n "$group" ] && [ -n "$server" ] && echo $server_base64 $group_base64 $remarks_base64 >> /tmp/all_onlineservers
	#echo ------
	#echo group: $group
	#echo remarks: $remarks
	#echo server: $server
	#echo server_port: $server_port
	#echo password: $password
	#echo ss_v2ray_plugin_tmp: $ss_v2ray_plugin_tmp
	#echo ss_v2ray_opts_tmp: $ss_v2ray_opts_tmp
	#echo ------
	[ -n "$incNY" ] && echo "$group" >> /tmp/all_group_info.txt || return 2
	[ -n "$group" ] && return 0 || return 1
}

update_ss_config(){
	isadded_server=$(</tmp/all_localservers grep -w $group_base64 | awk  '{print $1 , $4}' | grep -c "${server_base64} ${remarks_base64}"|head -n1)
	if [ "$isadded_server" == "0" ]; then
		add_ss_servers $1
		let addnum1+=1
		let addnum+=1
	else
		# 如果在本地的订阅节点中已经有该节点（用group, remarks和server去判断），检测下配置是否更改，如果更改，则更新配置
		local index=$(</tmp/all_localservers grep "$group_base64" | awk '{print $1 , $4, $3}' | grep "${server_base64} ${remarks_base64}" | awk '{print $3}' | head -n1)

		local i=0
		dbus set "ssconf_basic_mode_$index=$ssr_subscribe_mode"

		dbus_update_if_diff "ssconf_basic_name_$index" "$remarks" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_server_$index" "$server" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_port_$index" "$server_port" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_password_$index" "$password" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_method_$index" "$encrypt_method" && i=$((i+1))

		dbus_update_if_diff "ssconf_basic_ss_v2ray_$index" "$ss_v2ray_tmp" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_ss_v2ray_plugin_opts_$index" "$ss_v2ray_opts_tmp" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_ss_kcp_support_$index" "$ss_kcp_support_tmp" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_ss_udp_support_$index" "$ss_udp_support_tmp" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_ss_kcp_opts_$index" "$ss_kcp_opts_tmp" && i=$((i+1))

		dbus_update_if_diff "ssconf_basic_ss_sskcp_port_$index" "$ss_sskcp_port_tmp" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_ss_sskcp_server_$index" "$ss_sskcp_server_tmp" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_ss_ssudp_server_$index" "$ss_ssudp_server_tmp" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_ss_ssudp_port_$index" "$ss_ssudp_port_tmp" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_ss_ssudp_mtu_$index" "$ss_ssudp_mtu_tmp" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_ss_udp_opts_$index" "$ss_udp_opts_tmp" && i=$((i+1))

		#echo $i
		if [ "$i" -gt "0" ];then
			echo_date "修改 ss 节点：【$remarks】" && let updatenum1+=1 && let updatenum+=1
		else
			echo_date "ss 节点：【$remarks】 参数未发生变化，跳过！"
		fi
	fi
}

##################################################################################################
# ssr 节点添加解析并更新
##################################################################################################
add_ssr_servers(){
	[[ $1 -ge 1000 ]] &&  local group_index=$1 
	ssrindex_x=$(($(dbus list ssconf_basic_|grep _name_ |awk -v group_index=$((group_index+1000)) -F'[_=]' '{if($4<group_index)print$4}' |sort -rn|head -n1)+1))
	[[ $ssrindex_x -gt 1000 ]] && ssrindex_x=$((ssrindex_x%1000))
	ssrindex=$((ssrindex_x+group_index))
	dbus set ssconf_basic_name_$ssrindex=$remarks
	[[ $1 -ge 1000 ]] && dbus set ssconf_basic_group_$ssrindex=$group
	dbus set ssconf_basic_mode_$ssrindex=$ssr_subscribe_mode
	dbus set ssconf_basic_server_$ssrindex=$server
	dbus set ssconf_basic_port_$ssrindex=$server_port
	dbus set ssconf_basic_rss_protocol_$ssrindex=$protocol
	dbus set ssconf_basic_rss_protocol_param_$ssrindex=$protoparam
	dbus set ssconf_basic_method_$ssrindex=$encrypt_method
	dbus set ssconf_basic_rss_obfs_$ssrindex=$obfs
	dbus set ssconf_basic_type_$ssrindex="1"
	[ -n "$1" ] && dbus set ssconf_basic_rss_obfs_param_$ssrindex=${obfsparam%%#*}
	dbus set ssconf_basic_password_$ssrindex=$password
	echo_date SSR节点：新增加 【$remarks】 到节点列表第 $ssrindex_x 位。
}

get_ssr_config(){
	decode_link=$(base64decode_link $1)
	if [ -z "$decode_link" ];then
		echo_date "解析失败！！！"
		return 1
	fi

	group="$2"

	server=$(echo "$decode_link" |awk -F':' '{print $1}')
	server_port=$(echo "$decode_link" |awk -F':' '{print $2}')
	protocol=$(echo "$decode_link" |awk -F':' '{print $3}')
	encrypt_method=$(echo "$decode_link" |awk -F':' '{print $4}')
	obfs=$(echo "$decode_link" |awk -F':' '{print $5}'|sed 's/_compatible//g')
	password=$(base64decode_link $(echo "$decode_link" |awk -F':' '{print $6}'|awk -F'/' '{print $1}'))
	password=`echo $password|base64_encode`
	
	obfsparam_temp=$(echo "$decode_link" |awk -F':' '{print $6}'|grep -Eo "obfsparam.+"|sed 's/obfsparam=//g'|awk -F'&' '{print $1}')
	[ -n "$obfsparam_temp" ] && obfsparam=$(base64decode_link $obfsparam_temp) || obfsparam=''
	
	protoparam_temp=$(echo "$decode_link" |awk -F':' '{print $6}'|grep -Eo "protoparam.+"|sed 's/protoparam=//g'|awk -F'&' '{print $1}')
	[ -n "$protoparam_temp" ] && protoparam=$(base64decode_link $protoparam_temp|sed 's/_compatible//g') || protoparam=''
	
	remarks_temp=$(echo "$decode_link" |awk -F':' '{print $6}'|grep -Eo "remarks.+"|sed 's/remarks=//g'|awk -F'&' '{print $1}')
	[ -n "$(base64decode_link $remarks_temp)"  ] && remarks=$(base64decode_link $remarks_temp) 

	
	[ -n "$group" ] && group_base64=`echo $group | base64_encode | sed 's/ -//g'`
	[ -n "$server" ] && server_base64=`echo $server | base64_encode | sed 's/ -//g'`	
	[ -n "$remarks" ] && remarks_base64=`echo $remarks | base64_encode | sed 's/ -//g'`

	[ -n "$node_regexp" ] && incNY=`echo $remarks $server  | sed -n "$node_regexp"` || incNY="Y"

	#把全部服务器节点写入文件 /usr/share/shadowsocks/serverconfig/all_onlineservers
	[ -n "$incNY" ] && [ -n "$group" ] && [ -n "$server" ] && echo $server_base64 $group_base64 $remarks_base64 >> /tmp/all_onlineservers
	#echo ------
	#echo group: $group
	#echo remarks: $remarks
	#echo server: $server
	#echo server_port: $server_port
	#echo password: $password
	#echo encrypt_method: $encrypt_method
	#echo protocol: $protocol
	#echo protoparam: $protoparam
	#echo obfs: $obfs
	#echo obfsparam: $obfsparam
	#echo ------
	[ -n "$incNY" ] && echo "$group" >> /tmp/all_group_info.txt || return 2
	[ -n "$group" ] && return 0 || return 1

}

update_ssr_config(){
	isadded_server=$(</tmp/all_localservers grep -w "$group_base64" | awk '{print $1 , $4}' | grep -c "${server_base64} ${remarks_base64}" | head -n1)
	if [ "$isadded_server" == "0" ]; then
		add_ssr_servers "$1"
		[ "$ssr_subscribe_obfspara" == "0" ] && dbus set "ssconf_basic_rss_obfs_param_$ssrindex="
		[ "$ssr_subscribe_obfspara" == "1" ] && dbus set "ssconf_basic_rss_obfs_param_$ssrindex=${obfsparam%%#*}"
		[ "$ssr_subscribe_obfspara" == "2" ] && dbus set "ssconf_basic_rss_obfs_param_$ssrindex=${ssr_subscribe_obfspara_val%%#*}"
		let addnum2+=1
		let addnum+=1
	else
		# 如果在本地的订阅节点中已经有该节点（用group, remarks和server去判断），检测下配置是否更改，如果更改，则更新配置
		local index=$(</tmp/all_localservers grep "$group_base64" | awk '{print $1 , $4, $3}' | grep "${server_base64} ${remarks_base64}" | awk '{print $3}' | head -n1)

		local i=0

		# obfs_param：按你的逻辑处理（不计数）
		[ "$ssr_subscribe_obfspara" == "0" ] && dbus remove "ssconf_basic_rss_obfs_param_$index"
		[ "$ssr_subscribe_obfspara" == "1" ] && dbus set "ssconf_basic_rss_obfs_param_$index=${obfsparam%%#*}"
		[ "$ssr_subscribe_obfspara" == "2" ] && dbus set "ssconf_basic_rss_obfs_param_$index=${ssr_subscribe_obfspara_val%%#*}"

		# mode：保持不计数
		dbus set "ssconf_basic_mode_$index=$ssr_subscribe_mode"

		# 统一对比更新 + 计数
		dbus_update_if_diff "ssconf_basic_name_$index" "$remarks" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_port_$index" "$server_port" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_rss_protocol_$index" "$protocol" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_rss_protocol_param_$index" "$protoparam" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_method_$index" "$encrypt_method" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_rss_obfs_$index" "$obfs" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_password_$index" "$password" && i=$((i+1))

		if [ "$i" -gt "0" ]; then
		echo_date "修改SSR节点：【$remarks】" && let updatenum2+=1 && let updatenum+=1
		else
		echo_date "SSR节点：【$remarks】 参数未发生变化，跳过！"
		fi
	fi
}

##################################################################################################
# vmess 节点添加解析并更新
##################################################################################################
get_vmess_config(){
	decode_link=$(base64decode_link $1 | jq -c .)
	if [ -z "$decode_link" ];then
		echo_date "解析失败！！！"
		return 1
	fi
	#decode_link="$1"
	v2ray_group="$2"
	v2ray_v=$(echo "$decode_link" | sed -E 's/.*"v":"?([^,"]*)"?.*/\1/')
	v2ray_ps="$(echo "$decode_link" | sed -n 's/\\"/\&quot;/g;s|.*"ps":"\([^"]*\)".*|\1|p' | sed -e 's/&quot;/\"/g' | awk '{$1=$1;print}')"
	v2ray_add="$(echo "$decode_link" | sed 's/[ \t]*//g' | sed -E 's/.*"add":"?([^,"]*)"?.*/\1/')"
	v2ray_port=$(echo "$decode_link" | sed -E 's/.*"port":"?([^,"]*)"?.*/\1/')
	v2ray_id=$(echo "$decode_link" | sed -E 's/.*"id":"?([^,"]*)"?.*/\1/')
	v2ray_aid=$(echo "$decode_link" | sed -E 's/.*"aid":"?([^,"]*)"?.*/\1/')
	v2ray_net=$(echo "$decode_link" | sed -E 's/.*"net":"?([^,"]*)"?.*/\1/')
	v2ray_type=$(echo "$decode_link" | sed -E 's/.*"type":"?([^,"]*)"?.*/\1/')
	v2ray_tls_tmp=$(echo "$decode_link" | sed -E 's/.*"tls":"?([^,"]*)"?.*/\1/')
	[ "$v2ray_tls_tmp"x == "tls"x ] && v2ray_tls="tls" || v2ray_tls="none"
	
	if [ "$v2ray_v" == "2" ];then
		#echo_date "new format"
		v2ray_path=$(echo "$decode_link" | sed -n 's|.*"path":"\([^"]*\)".*|\1|p')
		v2ray_host=$(echo "$decode_link" | sed -n 's|.*"host":"\([^"]*\)".*|\1|p')
	else
		#echo_date "old format"
		case $v2ray_net in
		tcp)
			v2ray_host=$(echo "$decode_link" | sed -n 's|.*"host":"\([^"]*\)".*|\1|p')
			v2ray_path=""
			;;
		kcp)
			v2ray_host=""
			v2ray_path=$(echo "$decode_link" | sed -n 's|.*"path":"\([^"]*\)".*|\1|p')
			;;
		ws)
			v2ray_host_tmp=$(echo "$decode_link" | sed -n 's|.*"host":"\([^"]*\)".*|\1|p')
			if [ -n "$v2ray_host_tmp" ];then
				format_ws=`echo $v2ray_host_tmp|grep -E ";"`
				if [ -n "$format_ws" ];then
					v2ray_host=`echo $v2ray_host_tmp|cut -d ";" -f1`
					v2ray_path=`echo $v2ray_host_tmp|cut -d ";" -f1`
				else
					v2ray_host=""
					v2ray_path=$v2ray_host
				fi
			fi
			;;
		h2)
			v2ray_host=""
			v2ray_path=$(echo "$decode_link" | sed -n 's|.*"path":"\([^"]*\)".*|\1|p')
			;;
		grpc)
			v2ray_path=$(echo "$decode_link" | sed -n 's|.*"path":"\([^"]*\)".*|\1|p')
			;;			
		esac
	fi

	#把全部服务器节点编码后写入文件 /usr/share/shadowsocks/serverconfig/all_onlineservers
	[ -n "$v2ray_group" ] && group_base64=`echo $v2ray_group | base64_encode | sed 's/ -//g'`
	[ -n "$v2ray_add" ] && server_base64=`echo "$v2ray_add" | base64_encode | sed 's/ -//g'`	
	[ -n "$v2ray_ps" ] && remarks_base64=`echo "$v2ray_ps" | base64_encode | sed 's/ -//g'`

	[ -n "$node_regexp" ] && incNY=`echo "$v2ray_ps" "$v2ray_add"  | sed -n "$node_regexp"` || incNY="Y"
	[ -n "$incNY" ] && [ -n "$v2ray_group" ] && [ -n "$v2ray_add" ] && echo $server_base64 $group_base64 $remarks_base64 >> /tmp/all_onlineservers
	[ -n "$incNY" ] && echo "$v2ray_group" >> /tmp/all_group_info.txt || return 2
	[ -n "$v2ray_group" ] && return 0 || return 1


	#echo ------
	#echo v2ray_v: $v2ray_v
	#echo v2ray_ps: $v2ray_ps
	#echo v2ray_add: $v2ray_add
	#echo v2ray_port: $v2ray_port
	#echo v2ray_id: $v2ray_id
	#echo v2ray_net: $v2ray_net
	#echo v2ray_type: $v2ray_type
	#echo v2ray_host: $v2ray_host
	#echo v2ray_path: $v2ray_path
	#echo v2ray_tls: $v2ray_tls
	#echo ------
	
	[ -z "$v2ray_ps" -o -z "$v2ray_add" -o -z "$v2ray_port" -o -z "$v2ray_id" -o -z "$v2ray_aid" -o -z "$v2ray_net" -o -z "$v2ray_type" ] && return 1 || return 0
}

add_vmess_servers(){
	[[ $1 -ge 1000 ]] &&  local group_index=$1 
	v2rayindex_x=$(($(dbus list ssconf_basic_|grep _name_ |awk -v group_index=$((group_index+1000)) -F'[_=]' '{if($4<group_index)print$4}' |sort -rn|head -n1)+1))
	[[ $v2rayindex_x -gt 1000 ]] && v2rayindex_x=$((v2rayindex_x%1000))
	v2rayindex=$((v2rayindex_x+group_index))	
	[[ $1 -ge 1000 ]] && dbus set ssconf_basic_group_$v2rayindex=$v2ray_group
	dbus set ssconf_basic_type_$v2rayindex=3
	dbus set ssconf_basic_v2ray_protocol_$v2rayindex="vmess"
	if [ -n "$v2ray_group" ]; then
		dbus set ssconf_basic_allowinsecure_$v2rayindex=1
	else
		dbus set ssconf_basic_allowinsecure_$v2rayindex=0
	fi
	dbus set ssconf_basic_v2ray_mux_enable_$v2rayindex=0
	dbus set ssconf_basic_v2ray_use_json_$v2rayindex=0
	dbus set ssconf_basic_v2ray_security_$v2rayindex="auto"
	dbus set ssconf_basic_mode_$v2rayindex=$ssr_subscribe_mode
	dbus set ssconf_basic_name_$v2rayindex="$v2ray_ps"
	dbus set ssconf_basic_port_$v2rayindex=$v2ray_port
	dbus set ssconf_basic_server_$v2rayindex=$v2ray_add
	dbus set ssconf_basic_v2ray_uuid_$v2rayindex=$v2ray_id
	if [ -n "$v2ray_group" ]; then
		dbus set ssconf_basic_v2ray_alterid_$v2rayindex=0
	else
		dbus set ssconf_basic_v2ray_alterid_$v2rayindex=$v2ray_aid
	fi
	dbus set ssconf_basic_v2ray_network_security_$v2rayindex=$v2ray_tls
	dbus set ssconf_basic_v2ray_network_$v2rayindex=$v2ray_net
	case $v2ray_net in
	tcp)
		# tcp协议设置【 tcp伪装类型 (type)】和【伪装域名 (host)】
		dbus set ssconf_basic_v2ray_headtype_tcp_$v2rayindex=$v2ray_type
		[ -n "$v2ray_host" ] && dbus set ssconf_basic_v2ray_network_host_$v2rayindex=$v2ray_host
		;;
	kcp)
		# kcp协议设置【 kcp伪装类型 (type)】
		dbus set ssconf_basic_v2ray_headtype_kcp_$v2rayindex=$v2ray_type
		[ -n "$v2ray_path" ] && dbus set ssconf_basic_v2ray_network_path_$v2rayindex=$v2ray_path
		;;
	ws|h2)
		# ws/h2协议设置【 伪装域名 (host))】和【路径 (path)】
		[ -n "$v2ray_host" ] && dbus set ssconf_basic_v2ray_network_host_$v2rayindex=$v2ray_host
		[ -n "$v2ray_path" ] && dbus set ssconf_basic_v2ray_network_path_$v2rayindex=$v2ray_path
		;;
	grpc)
		# grpc协议设置【 grpc伪装类型 (type)】
		[ -n "$v2ray_path" ] && dbus set ssconf_basic_v2ray_serviceName_$v2rayindex=$v2ray_path
		;;
	esac
	echo_date v2ray节点：新增加 【$v2ray_ps】 到节点列表第 $v2rayindex_x 位。
}

update_vmess_config(){
	isadded_server=$(</tmp/all_localservers grep -w "$group_base64" | awk '{print $1 , $4}' | grep -c "${server_base64} ${remarks_base64}" | head -n1)
	if [ "$isadded_server" == "0" ]; then
		add_vmess_servers "$1"
		let addnum3+=1
		let addnum+=1
	else
		# 如果在本地的订阅节点中已经有该节点（用group, remarks和server去判断），检测下配置是否更改，如果更改，则更新配置
		local index=$(</tmp/all_localservers grep "$group_base64" | awk '{print $1 , $4, $3}' | grep "${server_base64} ${remarks_base64}" | awk '{print $3}' | head -n1)

		local i=0

		# mode：保持不计数
		dbus set "ssconf_basic_mode_$index=$ssr_subscribe_mode"

		# 基础字段：统一对比更新 + 计数
		dbus_update_if_diff "ssconf_basic_name_$index" "$v2ray_ps" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_server_$index" "$v2ray_add" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_port_$index" "$v2ray_port" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_v2ray_uuid_$index" "$v2ray_id" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_v2ray_alterid_$index" "$v2ray_aid" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_v2ray_network_security_$index" "$v2ray_tls" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_v2ray_network_$index" "$v2ray_net" && i=$((i+1))

		# 按“目标网络类型”走分支
		case "$v2ray_net" in
		tcp)
			# tcp协议
			dbus_update_if_diff "ssconf_basic_v2ray_headtype_tcp_$index" "$v2ray_type" && i=$((i+1))
			dbus_update_if_diff "ssconf_basic_v2ray_network_host_$index" "$v2ray_host" && i=$((i+1))
			;;
		kcp)
			# kcp协议
			dbus_update_if_diff "ssconf_basic_v2ray_headtype_kcp_$index" "$v2ray_type" && i=$((i+1))
			dbus_update_if_diff "ssconf_basic_v2ray_network_path_$index" "$v2ray_path" && i=$((i+1))
			;;
		ws|h2)
			# ws/h2协议
			dbus_update_if_diff "ssconf_basic_v2ray_network_host_$index" "$v2ray_host" && i=$((i+1))
			dbus_update_if_diff "ssconf_basic_v2ray_network_path_$index" "$v2ray_path" && i=$((i+1))
			;;
		grpc)
			# grpc协议：这里你用 v2ray_path 作为 serviceName
			dbus_update_if_diff "ssconf_basic_v2ray_serviceName_$index" "$v2ray_path" && i=$((i+1))
			;;
		esac

		if [ "$i" -gt "0" ]; then
		echo_date "修改v2ray节点：【$v2ray_ps】" && let updatenum3+=1 && let updatenum+=1
		else
		echo_date "v2ray节点：【$v2ray_ps】 参数未发生变化，跳过！"
		fi
	fi
	}


##################################################################################################
# trojan 节点添加解析并更新
##################################################################################################
get_trojan_config(){
	decode_link="$1"
	if [ -z "$decode_link" ];then
		echo_date "解析失败！！！"
		return 1
	fi

	group="$2"

	if [ -n "$(echo -n "$decode_link" | grep "#")" ];then
		remarks=$(echo -n $decode_link | awk -F'#' '{print $2}') 
		decode_link=$(echo -n $decode_link | awk -F'#' '{print $1}')		
	else
		remarks="$remarks" 
	fi

	server=$(echo "$decode_link" |awk -F':' '{print $1}'|awk -F'@' '{print $2}')
	server_port=$(echo "$decode_link" |awk -F':' '{print $2}' | awk -F'?' '{print $1}')
	password=$(echo "$decode_link" |awk -F':' '{print $1}'|awk -F'@' '{print $1}')
	password=`echo $password|base64_encode`
	#20201024+++
	sni=$(echo "$decode_link" | tr '?#&' '\n' | grep 'sni=' | awk -F'=' '{print $2}')
	peer=$(echo "$decode_link" | tr '?#&' '\n' | grep 'peer=' | awk -F'=' '{print $2}')
	v2ray_net=0
	binary="Trojan"

	[ -n "$group" ] && group_base64=`echo $group | base64_encode | sed 's/ -//g'`
	[ -n "$server" ] && server_base64=`echo $server | base64_encode | sed 's/ -//g'`
	[ -n "$remarks" ] && remarks_base64=`echo $remarks | base64_encode | sed 's/ -//g'`

	[ -n "$node_regexp" ] && incNY=`echo $remarks $server  | sed -n "$node_regexp"` || incNY="Y"

	#把全部服务器节点写入文件 /usr/share/shadowsocks/serverconfig/all_onlineservers
	[ -n "$incNY" ] && [ -n "$group" ] && [ -n "$server" ] && echo $server_base64 $group_base64 $remarks_base64 >> /tmp/all_onlineservers
	#echo ------
	#echo group: $group
	#echo remarks: $remarks
	#echo server: $server
	#echo server_port: $server_port
	#echo password: $password
	#echo ------
	[ -n "$incNY" ] && echo "$group" >> /tmp/all_group_info.txt || return 2
	[ -n "$group" ] && return 0 || return 1
}

add_trojan_servers(){
	[[ $1 -ge 1000 ]] &&  local group_index=$1 
	trojanindex_x=$(($(dbus list ssconf_basic_|grep _name_ |awk -v group_index=$((group_index+1000)) -F'[_=]' '{if($4<group_index)print$4}' |sort -rn|head -n1)+1))
	[[ $trojanindex_x -gt 1000 ]] && trojanindex_x=$((trojanindex_x%1000))
	trojanindex=$((trojanindex_x+group_index))
#	echo_date "添加 Trojan 节点：$remarks"
	[[ $1 -ge 1000 ]] && dbus set ssconf_basic_group_$trojanindex=$group
	dbus set ssconf_basic_name_$trojanindex=$remarks
	dbus set ssconf_basic_mode_$trojanindex=$ssr_subscribe_mode
	dbus set ssconf_basic_server_$trojanindex=$server
	dbus set ssconf_basic_port_$trojanindex=$server_port
	dbus set ssconf_basic_password_$trojanindex=$password
	dbus set ssconf_basic_type_$trojanindex="4"
	dbus set ssconf_basic_trojan_binary_$trojanindex=$binary
	dbus set ssconf_basic_trojan_sni_$trojanindex=$sni
	dbus set ssconf_basic_trojan_network_$trojanindex=$v2ray_net
	if [ -n "$group" ]; then
  		dbus set ssconf_basic_allowinsecure_$trojanindex=1
	else
		dbus set ssconf_basic_allowinsecure_$trojanindex=0
	fi
	echo_date "Trojan 节点：新增加 【$remarks】 到节点列表第 $trojanindex_x 位。"
}

update_trojan_config(){
	isadded_server=$(</tmp/all_localservers grep -w "$group_base64" | awk '{print $1 , $4}' | grep -c "${server_base64} ${remarks_base64}" | head -n1)
	if [ "$isadded_server" == "0" ]; then
		add_trojan_servers "$1"
		let addnum4+=1
		let addnum+=1
	else
		# 如果在本地的订阅节点中已经有该节点（用group, remarks和server去判断），检测下配置是否更改，如果更改，则更新配置
		local index=$(</tmp/all_localservers grep "$group_base64" | awk '{print $1 , $4, $3}' | grep "${server_base64} ${remarks_base64}" | awk '{print $3}' | head -n1)

		local i=0

		# mode：保持不计数
		dbus set "ssconf_basic_mode_$index=$ssr_subscribe_mode"

		# 基础字段：统一对比更新 + 计数
		dbus_update_if_diff "ssconf_basic_name_$index" "$remarks" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_server_$index" "$server" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_port_$index" "$server_port" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_password_$index" "$password" && i=$((i+1))

		dbus_update_if_diff "ssconf_basic_trojan_binary_$index" "$binary" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_trojan_network_$index" "$v2ray_net" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_trojan_sni_$index" "$sni" && i=$((i+1))

		if [ "$i" -gt "0" ]; then
		echo_date "修改 Trojan 节点：【$remarks】" && let updatenum4+=1 && let updatenum+=1
		else
		echo_date "Trojan 节点：【$remarks】 参数未发生变化，跳过！"
		fi
	fi
}


##################################################################################################
# Hysteria2 节点添加解析并更新
##################################################################################################
get_hysteria2_config(){
	decode_link="$1"
	if [ -z "$decode_link" ];then
		echo_date "解析失败！！！"
		return 1
	fi

	group="$2"

	if [ -n "$(echo -n "$decode_link" | grep "#")" ];then
		remarks=$(echo -n $decode_link | awk -F'#' '{print $2}') 
		decode_link=$(echo -n $decode_link | awk -F'#' '{print $1}')		
	else
		remarks="$remarks" 
	fi

	server=$(echo "$decode_link" |awk -F':' '{print $1}'|awk -F'@' '{print $2}')
	server_port=$(echo "$decode_link" |awk -F':' '{print $2}' | awk -F'\\/\\?' '{print $1}')
	password=$(echo "$decode_link" |awk -F':' '{print $1}'|awk -F'@' '{print $1}')
	password=`echo $password|base64_encode`
	#20201024+++
	sni=$(echo "$decode_link" | tr '?#&' '\n' | grep 'sni=' | awk -F'=' '{print $2}')
	insecure=$(echo "$decode_link" | tr '?#&' '\n' | grep 'insecure=' | awk -F'=' '{print $2}')
	v2ray_net=0
	binary="Hysteria2"
#	echo_date "服务器：$server" >> $LOG_FILE
#	echo_date "端口：$server_port" >> $LOG_FILE
#	echo_date "密码：$password" >> $LOG_FILE
#	echo_date "sni：$sni" >> $LOG_FILE
	#20201024---


	[ -n "$group" ] && group_base64=`echo $group | base64_encode | sed 's/ -//g'`
	[ -n "$server" ] && server_base64=`echo $server | base64_encode | sed 's/ -//g'`
	[ -n "$remarks" ] && remarks_base64=`echo $remarks | base64_encode | sed 's/ -//g'`

	[ -n "$node_regexp" ] && incNY=`echo $remarks $server  | sed -n "$node_regexp"` || incNY="Y"

	#把全部服务器节点写入文件 /usr/share/shadowsocks/serverconfig/all_onlineservers
	[ -n "$incNY" ] && [ -n "$group" ] && [ -n "$server" ] && echo $server_base64 $group_base64 $remarks_base64 >> /tmp/all_onlineservers
	#echo ------
	#echo group: $group
	#echo remarks: $remarks
	#echo server: $server
	#echo server_port: $server_port
	#echo password: $password
	#echo ------
	[ -n "$incNY" ] && echo "$group" >> /tmp/all_group_info.txt || return 2
	[ -n "$group" ] && return 0 || return 1
}

add_hysteria2_servers(){
	[[ $1 -ge 1000 ]] &&  local group_index=$1 
	hysteria2index_x=$(($(dbus list ssconf_basic_|grep _name_ |awk -v group_index=$((group_index+1000)) -F'[_=]' '{if($4<group_index)print$4}' |sort -rn|head -n1)+1))
	[[ $hysteria2index_x -gt 1000 ]] && hysteria2index_x=$((hysteria2index_x%1000))
	hysteria2index=$((hysteria2index_x+group_index))
#	echo_date "添加 Hysteria2 节点：$remarks"
	[[ $1 -ge 1000 ]] && dbus set ssconf_basic_group_$hysteria2index=$group
	dbus set ssconf_basic_name_$hysteria2index=$remarks
	dbus set ssconf_basic_mode_$hysteria2index=$ssr_subscribe_mode
	dbus set ssconf_basic_server_$hysteria2index=$server
	dbus set ssconf_basic_port_$hysteria2index=$server_port
	dbus set ssconf_basic_password_$hysteria2index=$password
	dbus set ssconf_basic_type_$hysteria2index="4"
	dbus set ssconf_basic_trojan_binary_$hysteria2index=$binary
	dbus set ssconf_basic_trojan_sni_$hysteria2index=$sni
	dbus set ssconf_basic_trojan_network_$hysteria2index=$v2ray_net
	dbus set ssconf_basic_allowinsecure_$hysteria2index=$insecure

	echo_date "Hysteria2 节点：新增加 【$remarks】 到节点列表第 $hysteria2index_x 位。"
}

update_hysteria2_config(){
	isadded_server=$(</tmp/all_localservers grep -w "$group_base64" | awk '{print $1 , $4}' | grep -c "${server_base64} ${remarks_base64}" | head -n1)
	if [ "$isadded_server" == "0" ]; then
		add_hysteria2_servers "$1"
		let addnum7+=1
		let addnum+=1
	else
		# 如果在本地的订阅节点中已经有该节点（用group, remarks和server去判断），检测下配置是否更改，如果更改，则更新配置
		local index=$(</tmp/all_localservers grep "$group_base64" | awk '{print $1 , $4, $3}' | grep "${server_base64} ${remarks_base64}" | awk '{print $3}' | head -n1)

		local i=0

		# mode：保持不计数
		dbus set "ssconf_basic_mode_$index=$ssr_subscribe_mode"

		# 基础字段：统一对比更新 + 计数
		dbus_update_if_diff "ssconf_basic_name_$index" "$remarks" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_server_$index" "$server" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_port_$index" "$server_port" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_password_$index" "$password" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_trojan_binary_$index" "$binary" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_trojan_network_$index" "$v2ray_net" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_trojan_sni_$index" "$sni" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_allowinsecure_$index" "$insecure" && i=$((i+1))

		if [ "$i" -gt "0" ]; then
		echo_date "修改 Hysteria2 节点：【$remarks】" && let updatenum7+=1 && let updatenum+=1
		else
		echo_date "Hysteria2 节点：【$remarks】 参数未发生变化，跳过！"
		fi
	fi
}

##################################################################################################
# AnyTLS 节点添加解析并更新
##################################################################################################
get_anytls_config(){
	decode_link="$1"
	if [ -z "$decode_link" ];then
		echo_date "解析失败！！！"
		return 1
	fi

	group="$2"

	if [ -n "$(echo -n "$decode_link" | grep "#")" ];then
		remarks=$(echo -n $decode_link | awk -F'#' '{print $2}')
		decode_link=$(echo -n $decode_link | awk -F'#' '{print $1}')
	else
		remarks="$remarks"
	fi

	link_body=$(echo "$decode_link" | awk -F'[?#]' '{print $1}')
	password=$(echo "$link_body" |awk -F'@' '{print $1}')
	server_part=$(echo "$link_body" |awk -F'@' '{print $2}')
	server=$(echo "$server_part" |awk -F':' '{print $1}' | awk -F'/' '{print $1}')
	server_port=$(echo "$server_part" |awk -F':' '{print $2}' | awk -F'/' '{print $1}')
	[ -z "$server_port" ] && server_port=443
	password=`echo $password|base64_encode`
	sni=$(echo "$decode_link" | tr '?#&' '\n' | grep '^sni=' | awk -F'=' '{print $2}')
	anytls_insecure=$(echo "$decode_link" | tr '?#&' '\n' | grep '^insecure=' | awk -F'=' '{print $2}' | tr 'A-Z' 'a-z')
	insecure=0
	[ "$anytls_insecure" = "1" -o "$anytls_insecure" = "true" ] && insecure=1
	v2ray_net=0
	binary="AnyTLS"

	[ -n "$group" ] && group_base64=`echo $group | base64_encode | sed 's/ -//g'`
	[ -n "$server" ] && server_base64=`echo $server | base64_encode | sed 's/ -//g'`
	[ -n "$remarks" ] && remarks_base64=`echo $remarks | base64_encode | sed 's/ -//g'`

	[ -n "$node_regexp" ] && incNY=`echo $remarks $server  | sed -n "$node_regexp"` || incNY="Y"

	[ -n "$incNY" ] && [ -n "$group" ] && [ -n "$server" ] && echo $server_base64 $group_base64 $remarks_base64 >> /tmp/all_onlineservers
	[ -n "$incNY" ] && echo "$group" >> /tmp/all_group_info.txt || return 2
	[ -n "$group" ] && return 0 || return 1
}

add_anytls_servers(){
	[[ $1 -ge 1000 ]] &&  local group_index=$1
	anytlsindex_x=$(($(dbus list ssconf_basic_|grep _name_ |awk -v group_index=$((group_index+1000)) -F'[_=]' '{if($4<group_index)print$4}' |sort -rn|head -n1)+1))
	[[ $anytlsindex_x -gt 1000 ]] && anytlsindex_x=$((anytlsindex_x%1000))
	anytlsindex=$((anytlsindex_x+group_index))
	[[ $1 -ge 1000 ]] && dbus set ssconf_basic_group_$anytlsindex=$group
	dbus set ssconf_basic_name_$anytlsindex=$remarks
	dbus set ssconf_basic_mode_$anytlsindex=$ssr_subscribe_mode
	dbus set ssconf_basic_server_$anytlsindex=$server
	dbus set ssconf_basic_port_$anytlsindex=$server_port
	dbus set ssconf_basic_password_$anytlsindex=$password
	dbus set ssconf_basic_type_$anytlsindex="4"
	dbus set ssconf_basic_trojan_binary_$anytlsindex=$binary
	dbus set ssconf_basic_trojan_sni_$anytlsindex=$sni
	dbus set ssconf_basic_allowinsecure_$anytlsindex=$insecure

	echo_date "AnyTLS 节点：新增加 【$remarks】 到节点列表第 $anytlsindex_x 位。"
}

update_anytls_config(){
	isadded_server=$(</tmp/all_localservers grep -w "$group_base64" | awk '{print $1 , $4}' | grep -c "${server_base64} ${remarks_base64}" | head -n1)
	if [ "$isadded_server" == "0" ]; then
		add_anytls_servers "$1"
		let addnum8+=1
		let addnum+=1
	else
		local index=$(</tmp/all_localservers grep "$group_base64" | awk '{print $1 , $4, $3}' | grep "${server_base64} ${remarks_base64}" | awk '{print $3}' | head -n1)

		local i=0
		dbus set "ssconf_basic_mode_$index=$ssr_subscribe_mode"

		dbus_update_if_diff "ssconf_basic_name_$index" "$remarks" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_server_$index" "$server" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_port_$index" "$server_port" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_password_$index" "$password" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_trojan_binary_$index" "$binary" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_trojan_sni_$index" "$sni" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_allowinsecure_$index" "$insecure" && i=$((i+1))

		if [ "$i" -gt "0" ]; then
		echo_date "修改 AnyTLS 节点：【$remarks】" && let updatenum8+=1 && let updatenum+=1
		else
		echo_date "AnyTLS 节点：【$remarks】 参数未发生变化，跳过！"
		fi
	fi
}

##################################################################################################
# vless 节点添加解析并更新
##################################################################################################

#测试链接格式
#vless://85dc5f20-111a-4274-3f0d-3ca40e000aff@test.aionas.tk:443?path=%2Fdyyjws&security=tls&encryption=none&host=test.aionas.tk&type=ws#test.aionas.tk_vless_ws

get_vless_config(){
	decode_link="$1"
	if [ -z "$decode_link" ];then
		echo_date "解析失败！！！"
		return 1
	fi

	vless_group="$2"


	if [ -n "$(echo -n "$decode_link" | grep "#")" ];then
		v2ray_ps=$(echo -n $decode_link | awk -F'#' '{print $2}' ) 				
	else
		v2ray_ps="$remarks" 
	fi

	v2ray_add=$(echo "$decode_link" |awk -F':' '{print $1}'|awk -F'@' '{print $2}')
	v2ray_port=$(echo "$decode_link" |awk -F':' '{print $2}' | awk -F'?' '{print $1}')
	v2ray_id=$(echo "$decode_link" |awk -F':' '{print $1}'|awk -F'@' '{print $1}')
	v2ray_net=$(echo "$decode_link" | tr '?&#' '\n' | grep 'type=' | awk -F'=' '{print $2}')
	v2ray_type=$(echo "$decode_link" | tr '?&#' '\n' | grep -iE '^headerType=' | awk -F'=' '{print $2}')
	v2ray_tls=$(echo "$decode_link" | tr '?&#' '\n' | grep 'security=' | awk -F'=' '{print $2}')	 # tls不会是关闭状态
	v2ray_flow=$(echo "$decode_link" | tr '?&#' '\n' | grep 'flow=' | awk -F'=' '{print $2}')
	v2ray_path=$(echo "$decode_link" | tr '?&#' '\n' | grep 'path=' | awk -F'=' '{print $2}')
	v2ray_seed=$(echo "$decode_link" | tr '?&#' '\n' | grep 'seed=' | awk -F'=' '{print $2}')
	v2ray_host=$(echo "$decode_link" | tr '?&#' '\n' | grep 'host=' | awk -F'=' '{print $2}')
	v2ray_tlshost=$(echo "$decode_link" | tr '?&#' '\n' | grep 'sni=' | awk -F'=' '{print $2}')
	v2ray_serviceName=$(echo "$decode_link" | tr '?&#' '\n' | grep 'serviceName=' | awk -F'=' '{print $2}')
	fingerprint=$(echo "$decode_link" | tr '?&#' '\n' | grep 'fp=' | awk -F'=' '{print $2}')
	xray_publicKey=$(echo "$decode_link" | tr '?&#' '\n' | grep 'pbk=' | awk -F'=' '{print $2}')
	xray_shortId=$(echo "$decode_link" | tr '?&#' '\n' | grep 'sid=' | awk -F'=' '{print $2}')
	#把全部服务器节点编码后写入文件 /usr/share/shadowsocks/serverconfig/all_onlineservers
	[ -n "$vless_group" ] && group_base64=`echo $vless_group | base64_encode | sed 's/ -//g'`
	[ -n "$v2ray_add" ] && server_base64=`echo $v2ray_add | base64_encode | sed 's/ -//g'`	
	[ -n "$v2ray_ps" ] && remarks_base64=`echo $v2ray_ps | base64_encode | sed 's/ -//g'`	

	[ -n "$node_regexp" ] && incNY=`echo $v2ray_ps $v2ray_add  | sed -n "$node_regexp"` || incNY="Y"
	[ -n "$incNY" ] && [ -n "$vless_group" ] && [ -n "$v2ray_add" ] && echo $server_base64 $group_base64 $remarks_base64 >> /tmp/all_onlineservers
	#echo ------
	#echo v2ray_ps: $v2ray_ps
	#echo v2ray_add: $v2ray_add
	#echo v2ray_port: $v2ray_port
	#echo v2ray_id: $v2ray_id
	#echo v2ray_net: $v2ray_net
	#echo v2ray_type: $v2ray_type
	#echo v2ray_host: $v2ray_host
	#echo v2ray_path: $v2ray_path
	#echo v2ray_tls: $v2ray_tls
	#echo v2ray_tlshost: $v2ray_tlshost
	#echo v2ray_serviceName: $v2ray_serviceName
	#echo ------
	[ -n "$incNY" ] && echo "$vless_group" >> /tmp/all_group_info.txt || return 2
	[ -n "$vless_group" ] && return 0 || return 1
	
	[ -z "$v2ray_ps" -o -z "$v2ray_add" -o -z "$v2ray_port" -o -z "$v2ray_id"  -o -z "$v2ray_tls"  -o -z "$v2ray_net" ] && return 1 || return 0
}

add_vless_servers(){
	[[ $1 -ge 1000 ]] &&  local group_index=$1
	v2rayindex_x=$(($(dbus list ssconf_basic_|grep _name_ |awk -v group_index=$((group_index+1000)) -F'[_=]' '{if($4<group_index)print$4}' |sort -rn|head -n1)+1))
	[[ $v2rayindex_x -gt 1000 ]] && v2rayindex_x=$((v2rayindex_x%1000))
	v2rayindex=$((v2rayindex_x+group_index))	

	[[ $1 -ge 1000 ]] && dbus set ssconf_basic_group_$v2rayindex=$vless_group
	dbus set ssconf_basic_type_$v2rayindex=3
	dbus set ssconf_basic_v2ray_protocol_$v2rayindex="vless"
	if [ -n "$vless_group" ]; then
		dbus set ssconf_basic_allowinsecure_$v2rayindex=1
	else
		dbus set ssconf_basic_allowinsecure_$v2rayindex=0
	fi
	dbus set ssconf_basic_v2ray_mux_enable_$v2rayindex=0
	dbus set ssconf_basic_v2ray_use_json_$v2rayindex=0
	dbus set ssconf_basic_v2ray_security_$v2rayindex="none"
	dbus set ssconf_basic_mode_$v2rayindex=$ssr_subscribe_mode
	dbus set ssconf_basic_name_$v2rayindex="$v2ray_ps"
	dbus set ssconf_basic_port_$v2rayindex=$v2ray_port
	dbus set ssconf_basic_server_$v2rayindex=$v2ray_add
	dbus set ssconf_basic_v2ray_uuid_$v2rayindex=$v2ray_id
	dbus set ssconf_basic_v2ray_network_security_$v2rayindex=$v2ray_tls
	dbus set ssconf_basic_v2ray_network_$v2rayindex=$v2ray_net
	[ -n "$fingerprint" ] && dbus set ssconf_basic_fingerprint_$v2rayindex=$fingerprint
	[ -n "$v2ray_tlshost" ] && dbus set ssconf_basic_v2ray_network_tlshost_$v2rayindex=$v2ray_tlshost
	
	case $v2ray_net in
	tcp)
		# vision or reality
		dbus set ssconf_basic_v2ray_headtype_tcp_$v2rayindex="$v2ray_type"
		case "$v2ray_tls" in
			tls)
				dbus set ssconf_basic_v2ray_network_flow_$v2rayindex=$v2ray_flow
				;;
			reality)
				dbus set ssconf_basic_v2ray_network_flow_$v2rayindex=$v2ray_flow
				dbus set ssconf_basic_xray_publicKey_$v2rayindex=$xray_publicKey
				dbus set ssconf_basic_xray_shortId_$v2rayindex=$xray_shortId
				;;
			*)
				
				;;
		esac

		#  @@ 不确定这个变量是否需要添加
		# [ -n "$v2ray_host" ] && dbus set ssconf_basic_v2ray_network_host_$v2rayindex=$v2ray_host 
		;;
				
	kcp)
		# kcp协议设置【 kcp伪装类型 (type)】
		dbus set ssconf_basic_v2ray_headtype_kcp_$v2rayindex=$v2ray_type
		[ -n "$v2ray_seed" ] && dbus set ssconf_basic_v2ray_network_path_$v2rayindex=$v2ray_seed
		;;
	grpc)
		# grpc协议设置【 grpc伪装类型 (type)】
		[ -n "$v2ray_serviceName" ] && dbus set ssconf_basic_v2ray_serviceName_$v2rayindex=$v2ray_serviceName
		;;
	ws|h2)
		# ws/h2协议设置【 伪装域名 (host))】和【路径 (path)】
		# ws + tls + CDN 会比较多，别的组合不熟悉
		[ -n "$v2ray_host" ] && dbus set ssconf_basic_v2ray_network_host_$v2rayindex=$v2ray_host
		[ -n "$v2ray_path" ] && dbus set ssconf_basic_v2ray_network_path_$v2rayindex=$v2ray_path
		;;
	esac
	echo_date vless节点：新增加 【$v2ray_ps】 到节点列表第 $v2rayindex_x 位。
}

update_vless_config(){
	isadded_server=$(</tmp/all_localservers grep -w "$group_base64" | awk '{print $1 , $4}' | grep -c "${server_base64} ${remarks_base64}" | head -n1)
	if [ "$isadded_server" == "0" ]; then
		add_vless_servers "$1"
		let addnum5+=1
		let addnum+=1
	else
		# 如果在本地的订阅节点中已经有该节点（用group, remarks和server去判断），检测下配置是否更改，如果更改，则更新配置
		local index=$(</tmp/all_localservers grep "$group_base64" | awk '{print $1 , $4, $3}' | grep "${server_base64} ${remarks_base64}" | awk '{print $3}' | head -n1)

		local i=0

		# mode：保持不计数
		dbus set "ssconf_basic_mode_$index=$ssr_subscribe_mode"

		# 通用字段：统一对比更新 + 计数
		dbus_update_if_diff "ssconf_basic_name_$index" "$v2ray_ps" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_server_$index" "$v2ray_add" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_port_$index" "$v2ray_port" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_v2ray_uuid_$index" "$v2ray_id" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_v2ray_network_security_$index" "$v2ray_tls" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_v2ray_network_$index" "$v2ray_net" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_v2ray_network_tlshost_$index" "$v2ray_tlshost" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_fingerprint_$index" "$fingerprint" && i=$((i+1))


		case "$v2ray_net" in
		tcp)
			# tcp协议
			dbus_update_if_diff "ssconf_basic_v2ray_headtype_tcp_$index" "$v2ray_type" && i=$((i+1))
			dbus_update_if_diff "ssconf_basic_v2ray_network_flow_$index" "$v2ray_flow" && i=$((i+1))
			dbus_update_if_diff "ssconf_basic_xray_publicKey_$index" "$xray_publicKey" && i=$((i+1))
			dbus_update_if_diff "ssconf_basic_xray_shortId_$index" "$xray_shortId" && i=$((i+1))
			;;
		kcp)
			# kcp协议
			dbus_update_if_diff "ssconf_basic_v2ray_headtype_kcp_$index" "$v2ray_type" && i=$((i+1))
			dbus_update_if_diff "ssconf_basic_v2ray_network_path_$index" "$v2ray_seed" && i=$((i+1))
			;;
		grpc)
			# grpc协议
			dbus_update_if_diff "ssconf_basic_v2ray_serviceName_$index" "$v2ray_serviceName" && i=$((i+1))
			;;
		ws|h2)
			# ws/h2协议
			dbus_update_if_diff "ssconf_basic_v2ray_network_host_$index" "$v2ray_host" && i=$((i+1))
			dbus_update_if_diff "ssconf_basic_v2ray_network_path_$index" "$v2ray_path" && i=$((i+1))
			;;
		esac

		if [ "$i" -gt "0" ]; then
		echo_date "修改vless节点：【$v2ray_ps】" && let updatenum5+=1 && let updatenum+=1
		else
		echo_date "vless节点：【$v2ray_ps】 参数未发生变化，跳过！"
		fi
	fi
}

##################################################################################################
# trojan go 节点添加解析并更新
##################################################################################################
get_trojan_go_config(){
	decode_link="$1"
	if [ -z "$decode_link" ];then
		echo_date "解析失败！！！"
		return 1
	fi

	group="$2"

	if [ -n "$(echo -n "$decode_link" | grep "#")" ];then
		remarks=$(echo -n $decode_link | awk -F'#' '{print $2}' ) 			
	else
		remarks="$remarks" 
	fi

	server=$(echo "$decode_link" |awk -F':' '{print $1}'|awk -F'@' '{print $2}')
	server_port=$(echo "$decode_link" |awk -F':' '{print $2}' | awk -F'[/?]' '{print $1}')
	password=$(echo "$decode_link" |awk -F':' '{print $1}'|awk -F'@' '{print $1}')
	password=`echo $password|base64_encode`
	v2ray_net=$(echo "$decode_link" | tr '?&#' '\n' | grep 'type=' | awk -F'=' '{print $2}')
	[ "$v2ray_net" == "ws" ] && v2ray_net=1 || v2ray_net=0
	v2ray_path=$(echo "$decode_link" | tr '?&#' '\n' | grep 'path=' | awk -F'=' '{print $2}')
	v2ray_host=$(echo "$decode_link" | tr '?&#' '\n' | grep 'host=' | awk -F'=' '{print $2}')
	sni=$(echo "$decode_link" | tr '?&#' '\n' | grep 'sni=' | awk -F'=' '{print $2}')
	fingerprint=$(echo "$decode_link" | tr '?&#' '\n' | grep 'fp=' | awk -F'=' '{print $2}')
	binary="Trojan-Go"

	[ -n "$group" ] && group_base64=`echo $group | base64_encode | sed 's/ -//g'`
	[ -n "$server" ] && server_base64=`echo $server | base64_encode | sed 's/ -//g'`	
	[ -n "$remarks" ] && remarks_base64=`echo $remarks | base64_encode | sed 's/ -//g'`

	[ -n "$node_regexp" ] && incNY=`echo $remarks $server  | sed -n "$node_regexp"` || incNY="Y"

	#把全部服务器节点写入文件 /usr/share/shadowsocks/serverconfig/all_onlineservers
	[ -n "$incNY" ] && [ -n "$group" ] && [ -n "$server" ] && echo $server_base64 $group_base64 $remarks_base64 >> /tmp/all_onlineservers
	
	
	#echo ------
	#echo group: $group
	#echo remarks: $remarks
	#echo server: $server
	#echo server_port: $server_port
	#echo password: $password
	#echo ------
	[ -n "$incNY" ] && echo "$group" >> /tmp/all_group_info.txt || return 2
	[ -n "$group" ] && return 0 || return 1
	[ -z "$server" -o -z "$remarks" -o -z "$server_port" -o -z "$password" ] && return 1 || return 0
}

add_trojan_go_servers(){
	[[ $1 -ge 1000 ]] &&  local group_index=$1
	trojangoindex_x=$(($(dbus list ssconf_basic_|grep _name_ |awk -v group_index=$((group_index+1000)) -F'[_=]' '{if($4<group_index)print$4}' |sort -rn|head -n1)+1))
	[[ $trojangoindex_x -gt 1000 ]] && trojangoindex_x=$((trojangoindex_x%1000))
	trojangoindex=$((trojangoindex_x+group_index))
#	echo_date "添加 Trojan-Go节点：$remarks"
	[[ $1 -ge 1000 ]] && dbus set ssconf_basic_group_$trojangoindex=$group
	dbus set ssconf_basic_name_$trojangoindex=$remarks
	dbus set ssconf_basic_mode_$trojangoindex=$ssr_subscribe_mode
	dbus set ssconf_basic_server_$trojangoindex=$server
	dbus set ssconf_basic_port_$trojangoindex=$server_port
	dbus set ssconf_basic_password_$trojangoindex=$password
	dbus set ssconf_basic_type_$trojangoindex="4"
	dbus set ssconf_basic_trojan_binary_$trojangoindex=$binary
	dbus set ssconf_basic_trojan_network_$trojangoindex=$v2ray_net  
	[ -n "$v2ray_host" ] && dbus set ssconf_basic_v2ray_network_host_$trojangoindex=$v2ray_host
	[ -n "$v2ray_path" ] && dbus set ssconf_basic_v2ray_network_path_$trojangoindex=$v2ray_path
	dbus set ssconf_basic_trojan_sni_$trojangoindex="$sni"
	dbus set ssconf_basic_fingerprint_$trojangoindex="$fingerprint"
	dbus set ssconf_basic_v2ray_mux_enable_$trojangoindex=0
	
	echo_date "Trojan Go节点：新增加 【$remarks】 到节点列表第 $trojangoindex_x 位。"
}

update_trojan_go_config(){
	isadded_server=$(</tmp/all_localservers grep -w $group_base64 | awk  '{print $1 , $4}' | grep -c "${server_base64} ${remarks_base64}"|head -n1)
	if [ "$isadded_server" == "0" ]; then
		add_trojan_go_servers $1
		let addnum6+=1
		let addnum+=1
	else
		# 如果在本地的订阅节点中已经有该节点（用group, remarks和server去判断），检测下配置是否更改，如果更改，则更新配置
		local index=$(</tmp/all_localservers grep $group_base64 | awk  '{print $1 , $4, $3}' | grep "${server_base64} ${remarks_base64}" |awk '{print $3}'|head -n1)

		local i=0
		dbus set ssconf_basic_mode_$index="$ssr_subscribe_mode"

		# 基础字段：name/server/port/password/binary/sni/v2ray_net/v2ray_host/v2ray_path/fingerprint
		dbus_update_if_diff "ssconf_basic_name_$index" "$remarks" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_server_$index" "$server" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_port_$index" "$server_port" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_password_$index" "$password" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_trojan_binary_$index" "$binary" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_trojan_sni_$index" "$sni" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_trojan_network_$index" "$v2ray_net" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_v2ray_network_host_$index" "$v2ray_host" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_v2ray_network_path_$index" "$v2ray_path" && i=$((i+1))
		dbus_update_if_diff "ssconf_basic_fingerprint_$index" "$fingerprint" && i=$((i+1))

		if [ "$i" -gt "0" ];then
			echo_date "修改 Trojan Go节点：【$remarks】" && let updatenum6+=1 && let updatenum+=1
		else
			echo_date "Trojan Go节点：【$remarks】 参数未发生变化，跳过！"
		fi
	fi
}

del_none_exist(){
# "删除订阅服务器已经不存在的节点"
	#[ -n "$group" ] && group_base64=`echo $group | base64_encode | sed 's/ -//g'`
	for localserver in $(</tmp/all_localservers  grep $group_base64 |awk '{print $1,$4}')
	do
		if [ "`</tmp/all_onlineservers  awk '{print $1,$3}' | grep -c "$localserver"`" -eq "0" ];then
			del_index=`</tmp/all_localservers awk '{print $1,$4,$3}' | grep $localserver | awk '{print $3}'`
			#for localindex in $(dbus list ssconf_basic_server|grep -v ssconf_basic_server_ip_|grep -w $localserver|cut -d "_" -f 4 |cut -d "=" -f1)
			for localindex in $del_index
			do 
			if [ -n "`dbus get ssconf_basic_name_$localindex`" ]; then
				echo_date 删除节点：`dbus get ssconf_basic_name_$localindex` ，因为该节点在订阅服务器上已经不存在...
				if [ "`dbus get ssconf_basic_type_$localindex`" = "0" ];then	#ss
					let delnum1+=1
				elif [ "`dbus get ssconf_basic_type_$localindex`" = "1" ];then	#ssr
					let delnum2+=1
				elif [ "`dbus get ssconf_basic_type_$localindex`" = "3" ] && [ "`dbus get ssconf_basic_v2ray_protocol_$localindex`" = "vmess" ];then	 #vmess
					let delnum3+=1
				elif [ "`dbus get ssconf_basic_type_$localindex`" = "3" ] && [ "`dbus get ssconf_basic_v2ray_protocol_$localindex`" = "vless" ];then	 #vless
					let delnum5+=1
				elif [ "`dbus get ssconf_basic_type_$localindex`" = "4" ] && [ "`dbus get ssconf_basic_trojan_binary_$localindex`" = "Trojan" ];then	 #trojan
					let delnum4+=1
				elif [ "`dbus get ssconf_basic_type_$localindex`" = "4" ] && [ "`dbus get ssconf_basic_trojan_binary_$localindex`" = "Trojan-Go" ];then	 #trojan go
					let delnum6+=1
				elif [ "`dbus get ssconf_basic_type_$localindex`" = "4" ] && [ "`dbus get ssconf_basic_trojan_binary_$localindex`" = "Hysteria2" ];then	 #Hysteria2
					let delnum7+=1	
				elif [ "`dbus get ssconf_basic_type_$localindex`" = "4" ] && [ "`dbus get ssconf_basic_trojan_binary_$localindex`" = "AnyTLS" ];then	 #AnyTLS
					let delnum8+=1
				fi
				
					dbus remove ssconf_basic_group_$localindex
					dbus remove ssconf_basic_koolgame_udp_$localindex
					dbus remove ssconf_basic_lbmode_$localindex
					dbus remove ssconf_basic_method_$localindex
					dbus remove ssconf_basic_mode_$localindex
					dbus remove ssconf_basic_name_$localindex
					dbus remove ssconf_basic_password_$localindex
					dbus remove ssconf_basic_port_$localindex
					dbus remove ssconf_basic_rss_obfs_$localindex
					dbus remove ssconf_basic_rss_obfs_param_$localindex
					dbus remove ssconf_basic_rss_protocol_$localindex
					dbus remove ssconf_basic_rss_protocol_param_$localindex
					dbus remove ssconf_basic_server_$localindex
					dbus remove ssconf_basic_server_ip_$localindex
					dbus remove ssconf_basic_ss_kcp_opts_$localindex
					dbus remove ssconf_basic_ss_kcp_support_$localindex
					dbus remove ssconf_basic_ss_sskcp_port_$localindex
					dbus remove ssconf_basic_ss_sskcp_server_$localindex
					dbus remove ssconf_basic_ss_ssudp_mtu_$localindex
					dbus remove ssconf_basic_ss_ssudp_port_$localindex
					dbus remove ssconf_basic_ss_ssudp_server_$localindex
					dbus remove ssconf_basic_ss_udp_opts_$localindex
					dbus remove ssconf_basic_ss_udp_support_$localindex
					dbus remove ssconf_basic_ss_v2ray_$localindex
					dbus remove ssconf_basic_ss_v2ray_plugin_$localindex
					dbus remove ssconf_basic_ss_v2ray_plugin_opts_$localindex
					dbus remove ssconf_basic_trojan_binary_$localindex	
					dbus remove ssconf_basic_trojan_network_$localindex
					dbus remove ssconf_basic_trojan_sni_$localindex
					dbus remove ssconf_basic_fingerprint_$localindex
					dbus remove ssconf_basic_type_$localindex
					dbus remove ssconf_basic_use_kcp_$localindex
					dbus remove ssconf_basic_use_lb_$localindex
					dbus remove ssconf_basic_v2ray_alterid_$localindex
					dbus remove ssconf_basic_v2ray_headtype_kcp_$localindex
					dbus remove ssconf_basic_v2ray_headtype_tcp_$localindex
					dbus remove ssconf_basic_v2ray_json_$localindex
					dbus remove ssconf_basic_v2ray_mux_concurrency_$localindex
					dbus remove ssconf_basic_v2ray_mux_enable_$localindex
					dbus remove ssconf_basic_allowinsecure_$localindex
					dbus remove ssconf_basic_v2ray_network_$localindex
					dbus remove ssconf_basic_v2ray_network_flow_$localindex
					dbus remove ssconf_basic_v2ray_network_host_$localindex
					dbus remove ssconf_basic_v2ray_network_path_$localindex
					dbus remove ssconf_basic_v2ray_serviceName_$localindex
					dbus remove ssconf_basic_v2ray_network_security_$localindex
					dbus remove ssconf_basic_v2ray_network_tlshost_$localindex
					dbus remove ssconf_basic_v2ray_protocol_$localindex
					dbus remove ssconf_basic_v2ray_security_$localindex
					dbus remove ssconf_basic_v2ray_use_json_$localindex
					dbus remove ssconf_basic_v2ray_uuid_$localindex
					dbus remove ssconf_basic_weight_$localindex
					dbus remove ssconf_basic_naive_protocol_$localindex
					dbus remove ssconf_basic_naive_user_$localindex
					dbus remove ssconf_basic_xray_publicKey_$localindex
					dbus remove ssconf_basic_xray_shortId_$localindex
				let delnum+=1
			fi 
			done
		fi
	done
}

remove_node_gap(){
	local SEQ=$(dbus list ssconf_basic_|grep _name_|cut -d "_" -f 4|cut -d "=" -f 1|sort -n)
	local MAX=$(dbus list ssconf_basic_|grep _name_|cut -d "_" -f 4|cut -d "=" -f 1|sort -rn|head -n1)
	local MAX_adj
	if [ -n "$MAX" ]; then
	if [ "$MAX" -gt 1000 ]; then
		MAX_adj=$((MAX%1000))
	else
		MAX_adj=$MAX
	fi
	else
	MAX_adj=0
	fi

	local NODE_NU=$(dbus list ssconf_basic_|grep _name_|wc -l)
	local KCP_NODE=`dbus get ss_kcp_node`
	
	#echo_date 现有节点顺序：$SEQ
	echo_date 最大节点序号：$MAX_adj
	echo_date 共有节点数量：$NODE_NU
	
	if [ "$MAX_adj" != "$NODE_NU" ];then
		echo_date 节点排序需要调整!
		echo_date 节点排序调整中...... 耐心等待
		local y=1
		for nu in $SEQ
		do
			[[ "$nu" -gt 1000 ]] && group_index_node=$((nu/1000*1000)) 
			[[ "$((group_index_node+0))" -gt 0 ]] && [ "$y" != "$nu" ] && [[ "$nu" -gt "$group_index_node" ]] && [[ "$y" -lt "$group_index_node" ]]  && y=$((y%1000+group_index_node))
			if [ "$y" != "$nu" ] ; then
				#echo_date 调整节点 $nu 到 节点 $y !
				[ -n "$(dbus get ssconf_basic_group_$nu)" ] && dbus set ssconf_basic_group_"$y"="$(dbus get ssconf_basic_group_$nu)" && dbus remove ssconf_basic_group_$nu
				[ -n "$(dbus get ssconf_basic_method_$nu)" ] && dbus set ssconf_basic_method_"$y"="$(dbus get ssconf_basic_method_$nu)" && dbus remove ssconf_basic_method_$nu
				[ -n "$(dbus get ssconf_basic_mode_$nu)" ] && dbus set ssconf_basic_mode_"$y"="$(dbus get ssconf_basic_mode_$nu)" && dbus remove ssconf_basic_mode_$nu
				[ -n "$(dbus get ssconf_basic_name_$nu)" ] && dbus set ssconf_basic_name_"$y"="$(dbus get ssconf_basic_name_$nu)" && dbus remove ssconf_basic_name_$nu
				[ -n "$(dbus get ssconf_basic_password_$nu)" ] && dbus set ssconf_basic_password_"$y"="$(dbus get ssconf_basic_password_$nu)" && dbus remove ssconf_basic_password_$nu
				[ -n "$(dbus get ssconf_basic_port_$nu)" ] && dbus set ssconf_basic_port_"$y"="$(dbus get ssconf_basic_port_$nu)" && dbus remove ssconf_basic_port_$nu
				[ -n "$(dbus get ssconf_basic_ss_v2ray_$nu)" ] && dbus set ssconf_basic_ss_v2ray_"$y"="$(dbus get ssconf_basic_ss_v2ray_$nu)"  && dbus remove ssconf_basic_ss_v2ray_$nu
				[ -n "$(dbus get ssconf_basic_ss_kcp_support_$nu)" ] && dbus set ssconf_basic_ss_kcp_support_"$y"="$(dbus get ssconf_basic_ss_kcp_support_$nu)"  && dbus remove ssconf_basic_ss_kcp_support_$nu
				[ -n "$(dbus get ssconf_basic_ss_udp_support_$nu)" ] && dbus set ssconf_basic_ss_udp_support_"$y"="$(dbus get ssconf_basic_ss_udp_support_$nu)"  && dbus remove ssconf_basic_ss_udp_support_$nu
				[ -n "$(dbus get ssconf_basic_ss_kcp_opts_$nu)" ] && dbus set ssconf_basic_ss_kcp_opts_"$y"="$(dbus get ssconf_basic_ss_kcp_opts_$nu)"  && dbus remove ssconf_basic_ss_kcp_opts_$nu
				[ -n "$(dbus get ssconf_basic_ss_sskcp_server_$nu)" ] && dbus set ssconf_basic_ss_sskcp_server_"$y"="$(dbus get ssconf_basic_ss_sskcp_server_$nu)"  && dbus remove ssconf_basic_ss_sskcp_server_$nu
				[ -n "$(dbus get ssconf_basic_ss_sskcp_port_$nu)" ] && dbus set ssconf_basic_ss_sskcp_port_"$y"="$(dbus get ssconf_basic_ss_sskcp_port_$nu)"  && dbus remove ssconf_basic_ss_sskcp_port_$nu
				[ -n "$(dbus get ssconf_basic_ss_ssudp_server_$nu)" ] && dbus set ssconf_basic_ss_ssudp_server_"$y"="$(dbus get ssconf_basic_ss_ssudp_server_$nu)"  && dbus remove ssconf_basic_ss_ssudp_server_$nu
				[ -n "$(dbus get ssconf_basic_ss_ssudp_port_$nu)" ] && dbus set ssconf_basic_ss_ssudp_port_"$y"="$(dbus get ssconf_basic_ss_ssudp_port_$nu)"  && dbus remove ssconf_basic_ss_ssudp_port_$nu
				[ -n "$(dbus get ssconf_basic_ss_ssudp_mtu_$nu)" ] && dbus set ssconf_basic_ss_ssudp_mtu_"$y"="$(dbus get ssconf_basic_ss_ssudp_mtu_$nu)"  && dbus remove ssconf_basic_ss_ssudp_mtu_$nu
				[ -n "$(dbus get ssconf_basic_ss_udp_opts_$nu)" ] && dbus set ssconf_basic_ss_udp_opts_"$y"="$(dbus get ssconf_basic_ss_udp_opts_$nu)"  && dbus remove ssconf_basic_ss_udp_opts_$nu
				[ -n "$(dbus get ssconf_basic_rss_obfs_$nu)" ] && dbus set ssconf_basic_rss_obfs_"$y"="$(dbus get ssconf_basic_rss_obfs_$nu)" && dbus remove ssconf_basic_rss_obfs_$nu
				[ -n "$(dbus get ssconf_basic_rss_obfs_param_$nu)" ] && dbus set ssconf_basic_rss_obfs_param_"$y"="$(dbus get ssconf_basic_rss_obfs_param_$nu)" && dbus remove ssconf_basic_rss_obfs_param_$nu
				[ -n "$(dbus get ssconf_basic_rss_protocol_$nu)" ] && dbus set ssconf_basic_rss_protocol_"$y"="$(dbus get ssconf_basic_rss_protocol_$nu)" && dbus remove ssconf_basic_rss_protocol_$nu
				[ -n "$(dbus get ssconf_basic_rss_protocol_param_$nu)" ] && dbus set ssconf_basic_rss_protocol_param_"$y"="$(dbus get ssconf_basic_rss_protocol_param_$nu)" && dbus remove ssconf_basic_rss_protocol_param_$nu
				[ -n "$(dbus get ssconf_basic_server_$nu)" ] && dbus set ssconf_basic_server_"$y"="$(dbus get ssconf_basic_server_$nu)" && dbus remove ssconf_basic_server_$nu
				[ -n "$(dbus get ssconf_basic_server_ip_$nu)" ] && dbus set ssconf_basic_server_ip_"$y"="$(dbus get ssconf_basic_server_ip_$nu)" && dbus remove ssconf_basic_server_ip_$nu
				[ -n "$(dbus get ssconf_basic_ss_v2ray_plugin_$nu)" ] && dbus set ssconf_basic_ss_v2ray_plugin_"$y"="$(dbus get ssconf_basic_ss_v2ray_plugin_$nu)" && dbus remove ssconf_basic_ss_v2ray_plugin_$nu
				[ -n "$(dbus get ssconf_basic_ss_v2ray_plugin_opts_$nu)" ] && dbus set ssconf_basic_ss_v2ray_plugin_opts_"$y"="$(dbus get ssconf_basic_ss_v2ray_plugin_opts_$nu)" && dbus remove ssconf_basic_ss_v2ray_plugin_opts_$nu
				[ -n "$(dbus get ssconf_basic_use_kcp_$nu)" ] && dbus set ssconf_basic_use_kcp_"$y"="$(dbus get ssconf_basic_use_kcp_$nu)" && dbus remove ssconf_basic_use_kcp_$nu
				[ -n "$(dbus get ssconf_basic_use_lb_$nu)" ] && dbus set ssconf_basic_use_lb_"$y"="$(dbus get ssconf_basic_use_lb_$nu)" && dbus remove ssconf_basic_use_lb_$nu
				[ -n "$(dbus get ssconf_basic_lbmode_$nu)" ] && dbus set ssconf_basic_lbmode_"$y"="$(dbus get ssconf_basic_lbmode_$nu)" && dbus remove ssconf_basic_lbmode_$nu
				[ -n "$(dbus get ssconf_basic_weight_$nu)" ] && dbus set ssconf_basic_weight_"$y"="$(dbus get ssconf_basic_weight_$nu)" && dbus remove ssconf_basic_weight_$nu
				[ -n "$(dbus get ssconf_basic_koolgame_udp_$nu)" ] && dbus set ssconf_basic_koolgame_udp_"$y"="$(dbus get ssconf_basic_koolgame_udp_$nu)" && dbus remove ssconf_basic_koolgame_udp_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_use_json_$nu)" ] && dbus set ssconf_basic_v2ray_use_json_"$y"="$(dbus get ssconf_basic_v2ray_use_json_$nu)" && dbus remove ssconf_basic_v2ray_use_json_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_uuid_$nu)" ] && dbus set ssconf_basic_v2ray_uuid_"$y"="$(dbus get ssconf_basic_v2ray_uuid_$nu)" && dbus remove ssconf_basic_v2ray_uuid_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_alterid_$nu)" ] && dbus set ssconf_basic_v2ray_alterid_"$y"="$(dbus get ssconf_basic_v2ray_alterid_$nu)" && dbus remove ssconf_basic_v2ray_alterid_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_security_$nu)" ] && dbus set ssconf_basic_v2ray_security_"$y"="$(dbus get ssconf_basic_v2ray_security_$nu)" && dbus remove ssconf_basic_v2ray_security_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_network_$nu)" ] && dbus set ssconf_basic_v2ray_network_"$y"="$(dbus get ssconf_basic_v2ray_network_$nu)" && dbus remove ssconf_basic_v2ray_network_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_headtype_tcp_$nu)" ] && dbus set ssconf_basic_v2ray_headtype_tcp_"$y"="$(dbus get ssconf_basic_v2ray_headtype_tcp_$nu)" && dbus remove ssconf_basic_v2ray_headtype_tcp_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_headtype_kcp_$nu)" ] && dbus set ssconf_basic_v2ray_headtype_kcp_"$y"="$(dbus get ssconf_basic_v2ray_headtype_kcp_$nu)" && dbus remove ssconf_basic_v2ray_headtype_kcp_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_serviceName_$nu)" ] && dbus set ssconf_basic_v2ray_serviceName_"$y"="$(dbus get ssconf_basic_v2ray_serviceName_$nu)" && dbus remove ssconf_basic_v2ray_serviceName_$nu	
				[ -n "$(dbus get ssconf_basic_v2ray_network_path_$nu)" ] && dbus set ssconf_basic_v2ray_network_path_"$y"="$(dbus get ssconf_basic_v2ray_network_path_$nu)" && dbus remove ssconf_basic_v2ray_network_path_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_network_host_$nu)" ] && dbus set ssconf_basic_v2ray_network_host_"$y"="$(dbus get ssconf_basic_v2ray_network_host_$nu)" && dbus remove ssconf_basic_v2ray_network_host_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_network_security_$nu)" ] && dbus set ssconf_basic_v2ray_network_security_"$y"="$(dbus get ssconf_basic_v2ray_network_security_$nu)" && dbus remove ssconf_basic_v2ray_network_security_$nu
				[ -n "$(dbus get ssconf_basic_allowinsecure_$nu)" ] && dbus set ssconf_basic_allowinsecure_"$y"="$(dbus get ssconf_basic_allowinsecure_$nu)" && dbus remove ssconf_basic_allowinsecure_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_mux_enable_$nu)" ] && dbus set ssconf_basic_v2ray_mux_enable_"$y"="$(dbus get ssconf_basic_v2ray_mux_enable_$nu)" && dbus remove ssconf_basic_v2ray_mux_enable_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_mux_concurrency_$nu)" ] && dbus set ssconf_basic_v2ray_mux_concurrency_"$y"="$(dbus get ssconf_basic_v2ray_mux_concurrency_$nu)" && dbus remove ssconf_basic_v2ray_mux_concurrency_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_json_$nu)" ] && dbus set ssconf_basic_v2ray_json_"$y"="$(dbus get ssconf_basic_v2ray_json_$nu)" && dbus remove ssconf_basic_v2ray_json_$nu
				[ -n "$(dbus get ssconf_basic_trojan_binary_$nu)" ] && dbus set ssconf_basic_trojan_binary_"$y"="$(dbus get ssconf_basic_trojan_binary_$nu)" && dbus remove ssconf_basic_trojan_binary_$nu
				[ -n "$(dbus get ssconf_basic_trojan_network_$nu)" ] && dbus set ssconf_basic_trojan_network_"$y"="$(dbus get ssconf_basic_trojan_network_$nu)" && dbus remove ssconf_basic_trojan_network_$nu
				[ -n "$(dbus get ssconf_basic_trojan_sni_$nu)" ] && dbus set ssconf_basic_trojan_sni_"$y"="$(dbus get ssconf_basic_trojan_sni_$nu)" && dbus remove ssconf_basic_trojan_sni_$nu
				[ -n "$(dbus get ssconf_basic_fingerprint_$nu)" ] && dbus set ssconf_basic_fingerprint_"$y"="$(dbus get ssconf_basic_fingerprint_$nu)" && dbus remove ssconf_basic_fingerprint_$nu
				[ -n "$(dbus get ssconf_basic_type_$nu)" ] && dbus set ssconf_basic_type_"$y"="$(dbus get ssconf_basic_type_$nu)" && dbus remove ssconf_basic_type_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_protocol_$nu)" ] && dbus set ssconf_basic_v2ray_protocol_"$y"="$(dbus get ssconf_basic_v2ray_protocol_$nu)" && dbus remove ssconf_basic_v2ray_protocol_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_network_tlshost_$nu)" ] && dbus set ssconf_basic_v2ray_network_tlshost_"$y"="$(dbus get ssconf_basic_v2ray_network_tlshost_$nu)"  && dbus remove ssconf_basic_v2ray_network_tlshost_$nu
				[ -n "$(dbus get ssconf_basic_v2ray_network_flow_$nu)" ] && dbus set ssconf_basic_v2ray_network_flow_"$y"="$(dbus get ssconf_basic_v2ray_network_flow_$nu)"  && dbus remove ssconf_basic_v2ray_network_flow_$nu
				[ -n "$(dbus get ssconf_basic_naive_protocol_$nu)" ] && dbus set ssconf_basic_naive_protocol_"$y"="$(dbus get ssconf_basic_naive_protocol_$nu)" && dbus remove ssconf_basic_naive_protocol_$nu
				[ -n "$(dbus get ssconf_basic_naive_user_$nu)" ] && dbus set ssconf_basic_naive_user_"$y"="$(dbus get ssconf_basic_naive_user_$nu)" && dbus remove ssconf_basic_naive_user_$nu
				[ -n "$(dbus get ssconf_basic_xray_publicKey_$nu)" ] && dbus set ssconf_basic_xray_publicKey_"$y"="$(dbus get ssconf_basic_xray_publicKey_$nu)" && dbus remove ssconf_basic_xray_publicKey_$nu
				[ -n "$(dbus get ssconf_basic_xray_shortId_$nu)" ] && dbus set ssconf_basic_xray_shortId_"$y"="$(dbus get ssconf_basic_xray_shortId_$nu)" && dbus remove ssconf_basic_xray_shortId_$nu

				usleep 100000
				# change node nu
				if [ "$nu" == "$ssconf_basic_node" ];then
					dbus set ssconf_basic_node="$y"
				fi
			fi
			let y+=1
		done
	else
		echo_date 节点排序正确!
	fi
}

open_socks_23456(){
	socksopen_a=`netstat -nlp|grep -w 23456|grep -E "local|v2ray"`
	if [ -z "$socksopen_a" ];then
		if [ "$ss_basic_type" == "1" ];then
			SOCKS_FLAG=1
			echo_date 开启ssr-local，提供socks5代理端口：23456
			rss-local -l 23456 -c $CONFIG_FILE -u -f /var/run/sslocal1.pid >/dev/null 2>&1
		elif  [ "$ss_basic_type" == "0" ];then
			SOCKS_FLAG=2
			echo_date 开启ss-local，提供socks5代理端口：23456
			if [ "$ss_basic_ss_v2ray_plugin" == "0" ];then
				ss-local -l 23456 -c $CONFIG_FILE -u -f /var/run/sslocal1.pid >/dev/null 2>&1
			else
				ss-local -l 23456 -c $CONFIG_FILE $ARG_V2RAY_PLUGIN -u -f /var/run/sslocal1.pid >/dev/null 2>&1
			fi
		fi
	fi
	sleep 2
}

get_type_name() {
	case "$1" in
		0)
			echo "SS"
		;;
		1)
			echo "SSR"
		;;
		2)
			echo "koolgame"
		;;
		3)
			echo "v2ray"
		;;
		4)
			echo "trojan"
		;;
	esac
}

get_oneline_rule_now(){
	# 节点订阅
	local ssr_subscribe_link=`echo "$1" | awk -F'~~' '{ print $1 }'`
	LINK_FORMAT=`echo "$ssr_subscribe_link" | grep -E "^http://|^https://"`
	node_regexp=`echo "$1" | awk -F'~~' '{ print $2 }'`
	[ -z "$LINK_FORMAT" ] && return 4
	
	echo_date "开始更新在线订阅列表..." 
	echo_date "开始下载订阅链接到本地临时文件，请稍等..."
	rm -rf /tmp/ssr_subscribe_file* >/dev/null 2>&1
	
	if [ "$ss_basic_online_links_goss" == "1" ];then
		open_socks_23456
		socksopen_b=`netstat -nlp|grep -w 23456|grep -E "local|xray|naive|hysteria|anytls"`
		if [ -n "$socksopen_b" ];then
			echo_date "使用$(get_type_name $ss_basic_type)提供的socks代理网络下载..."
			curl -k --connect-timeout 8 -s -A "v2rayN" -L --socks5-hostname 127.0.0.1:23456 $ssr_subscribe_link > /tmp/ssr_subscribe_file.txt
		else
			echo_date "没有可用的socks5代理端口，改用常规网络下载..."
			curl -k --connect-timeout 8 -s -A "v2rayN" -L $ssr_subscribe_link > /tmp/ssr_subscribe_file.txt
		fi
	else
		echo_date "使用常规网络下载..."
		curl -k --connect-timeout 8 -s -A "v2rayN" -L $ssr_subscribe_link > /tmp/ssr_subscribe_file.txt
	fi

	#虽然为0但是还是要检测下是否下载到正确的内容
	if [ "$?" == "0" ];then
		#订阅地址有跳转
		blank=`</tmp/ssr_subscribe_file.txt grep -E " |Redirecting|301"`
		if [ -n "$blank" ];then
			echo_date 订阅链接可能有跳转，尝试更换wget进行下载...
			rm /tmp/ssr_subscribe_file.txt
			if [ "`echo $ssr_subscribe_link|grep ^https`" ];then
				wget --no-check-certificate -qO /tmp/ssr_subscribe_file.txt $ssr_subscribe_link
			else
				wget -qO /tmp/ssr_subscribe_file.txt $ssr_subscribe_link
			fi
		fi
		#下载为空...
		if [ -z "`cat /tmp/ssr_subscribe_file.txt`" ];then
			echo_date 下载为空...
			return 3
		fi
		#产品信息错误
		wrong1=`</tmp/ssr_subscribe_file.txt grep "{"`
		wrong2=`</tmp/ssr_subscribe_file.txt grep "<"`
		if [ -n "$wrong1" -o -n "$wrong2" ];then
			return 2
		fi
	else
		return 1
	fi

	if [ "$?" == "0" ];then
		echo_date 下载订阅成功...
		echo_date 开始解析节点信息...
		base64decode_link `cat /tmp/ssr_subscribe_file.txt` | urldecode | sed 's/[\r\n ]//g' > /tmp/ssr_subscribe_file_temp1.txt

		maxnum=$(</tmp/ssr_subscribe_file_temp1.txt grep "MAX=" | awk -F"=" '{print $2}' | grep -Eo "[0-9]+")
#		maxnum=5
		if [ -n "$maxnum" ]; then
			</tmp/ssr_subscribe_file_temp1.txt sed '/MAX=/d' | shuf -n $maxnum > /tmp/ssr_subscribe_file_temp2.txt && mv  /tmp/ssr_subscribe_file_temp2.txt  /tmp/ssr_subscribe_file_temp1.txt
		fi


		NODE_NU_online=$(</tmp/ssr_subscribe_file_temp1.txt grep -cE '^ss://|^ssr://|^vmess://|^trojan://|^vless://|^trojan-go://|^hysteria2://|^hy2://|^anytls://')
		echo_date "检测到ShadowSocks节点格式，共计${NODE_NU_online}个节点..."

		if [  "$NODE_NU_online" = "0" ] ; then
			return 3
		else	
			# use domain as group
			group=`echo $ssr_subscribe_link|awk -F'[/:#]' '{print $4}'`
			
			# 储存对应订阅链接的group信息
			dbus set ss_online_group_$url_count=$group
			echo $group >> /tmp/group_info.txt
			
			remarks='AutoSuB'
			group_index=$((url_count*1000))
			# 提取节点
			grep -E '^ss://|^ssr://|^vmess://|^trojan://|^vless://|^trojan-go://|^hysteria2://|^hy2://|^anytls://' /tmp/ssr_subscribe_file_temp1.txt >  /tmp/ssr_subscribe_file_temp2.txt &&  mv  /tmp/ssr_subscribe_file_temp2.txt  /tmp/ssr_subscribe_file_temp1.txt

			# 检测ss ssr vmess trojan vless trojan-go hysteria2 anytls
			while read -r line
			do 
				link=""
				decode_link=""

				NODE_FORMAT="${line%%://*}"
				NODE_FORMAT="${NODE_FORMAT//-/_}"
				[ "$NODE_FORMAT" = "hy2" ] && NODE_FORMAT="hysteria2"
				link="${line#*://}"                  

				if [ -n "$NODE_FORMAT" ] && [ -n "$link" ]; then
					get_${NODE_FORMAT}_config $link "$group"
					local get_res=$? 
					if [ "$get_res" == "0" ]; then 
						update_${NODE_FORMAT}_config $group_index
				#	elif [ "$get_res" == "2" ]; then
					#	echo_date "节点名称不满足自定义关键字或正则表达式，被排除。"
					elif [ "$get_res" == "1" ]; then
						echo_date "检测到一个错误节点，已经跳过！"
					fi
				else
					echo_date "解析失败！！！"
				fi	
			done < /tmp/ssr_subscribe_file_temp1.txt
			
			# 去除订阅服务器上已经删除，或者用户自定义表达式未包含的节点
			del_none_exist

			USER_ADD=$(($(dbus list ssconf_basic_|grep _name_|wc -l) - $(dbus list ssconf_basic_|grep _group_|wc -l))) || 0
			ONLINE_GET=$(dbus list ssconf_basic_|grep _group_|wc -l) || 0
			
			echo_date "本次更新订阅来源 【$group】:"
			 if [ "${addnum1}${updatenum1}${delnum1}" != "000" ];then 
			 echo_date " 新增SS节点 $addnum1 个，修改 $updatenum1 个，删除 $delnum1 个；"
			 fi
			 if [ "${addnum2}${updatenum2}${delnum2}" != "000" ];then 
			 echo_date " 新增SSR节点 $addnum2 个，修改 $updatenum2 个，删除 $delnum2 个；"
			 fi
			 if [ "${addnum3}${updatenum3}${delnum3}" != "000" ];then 
			 echo_date " 新增VMESS节点 $addnum3 个，修改 $updatenum3 个，删除 $delnum3 个；"
			 fi
			 if [ "${addnum4}${updatenum4}${delnum4}" != "000" ];then 
			 echo_date " 新增Trojan节点 $addnum4 个，修改 $updatenum4 个，删除 $delnum4 个；"
			 fi
			 if [ "${addnum5}${updatenum5}${delnum5}" != "000" ];then 
			 echo_date " 新增VLESS节点 $addnum5 个，修改 $updatenum5 个，删除 $delnum5 个；"
			 fi
			 if [ "${addnum6}${updatenum6}${delnum6}" != "000" ];then 
			 echo_date " 新增Trojan-Go节点 $addnum6 个，修改 $updatenum6 个，删除 $delnum6 个；"
			 fi
			 if [ "${addnum7}${updatenum7}${delnum7}" != "000" ];then 
			 echo_date " 新增Hysteria2节点 $addnum7 个，修改 $updatenum7 个，删除 $delnum7 个；"
			 fi
			 if [ "${addnum8}${updatenum8}${delnum8}" != "000" ];then
			 echo_date " 新增AnyTLS节点 $addnum8 个，修改 $updatenum8 个，删除 $delnum8 个；"
			 fi
			echo_date "现共有手动添加的ShadowSocks节点：$USER_ADD 个；"
			echo_date "现共有来自订阅的ShadowSocks节点：$ONLINE_GET 个；"
			echo_date "在线订阅列表更新完成!"	
		fi
	else
		return 1
	fi
}

start_update(){
	prepare
	rm -f /tmp/ssr_subscribe_file.txt >/dev/null 2>&1
	rm -f /tmp/ssr_subscribe_file_temp1.txt >/dev/null 2>&1
	rm -f /tmp/all_localservers >/dev/null 2>&1
	rm -f /tmp/all_onlineservers >/dev/null 2>&1
	rm -f /tmp/all_group_info.txt >/dev/null 2>&1
	rm -f /tmp/group_info.txt >/dev/null 2>&1
#	usleep 250000
	echo_date 收集本地节点名到文件
	LOCAL_NODES=`dbus list ssconf_basic_|grep _group_|cut -d "_" -f 4|cut -d "=" -f 1|sort -n`
	if [ -n "$LOCAL_NODES" ];then
		for LOCAL_NODE in $LOCAL_NODES
		do
			# write: server group nu
			echo `dbus get ssconf_basic_server_$LOCAL_NODE|base64_encode` `dbus get ssconf_basic_group_$LOCAL_NODE|base64_encode`| eval echo `sed 's/$/ $LOCAL_NODE/g'` `dbus get ssconf_basic_name_$LOCAL_NODE|base64_encode`>> /tmp/all_localservers
		done
	else
		touch /tmp/all_localservers
	fi
	
	url_count=0
	online_url_nu=`dbus get ss_online_links|base64_decode|sed -e 's/$/\n/' -e '/^$/d'|wc -l`
	#echo_date online_url_nu $online_url_nu
	until [ "$url_count" == "$online_url_nu" ]
	do
		url_count=$((url_count+1))

		url=`dbus get ss_online_links|base64_decode|awk '{print $1}'|sed -n "$url_count p"|sed '/^#/d'`
		[ -z "$url" ] && continue
		echo_date "==================================================================="
		echo_date "				服务器订阅程序(Shell by stones & sadog)"
		echo_date "==================================================================="
		echo_date "从 $url 获取订阅..."
		addnum=0 ; addnum1=0 ; addnum2=0 ; addnum3=0 ; addnum4=0 ; addnum5=0; addnum6=0; addnum7=0; addnum8=0
		updatenum=0 ; updatenum1=0 ; updatenum2=0 ; updatenum3=0 ; updatenum4=0 ; updatenum5=0; updatenum6=0; updatenum7=0; updatenum8=0
		delnum=0 ; delnum1=0 ; delnum2=0 ; delnum3=0 ; delnum4=0 ; delnum5=0; delnum6=0; delnum7=0; delnum8=0
		
		get_oneline_rule_now "$url"

		case $? in
		0)
			continue
			;;
		2)
			echo_date "无法获取产品信息！请检查你的服务商是否更换了订阅链接！"
			rm -rf /tmp/ssr_subscribe_file.txt >/dev/null 2>&1 &
			let DEL_SUBSCRIBE+=1
			sleep 1
			echo_date "退出订阅程序..."
			;;
		3)
			echo_date "该订阅链接不包含任何节点信息！请检查你的服务商是否更换了订阅链接！"
			rm -rf /tmp/ssr_subscribe_file.txt >/dev/null 2>&1 &
			let DEL_SUBSCRIBE+=1
			sleep 1
			echo_date "退出订阅程序..."
			;;
		4)
			echo_date "订阅地址错误！检测到你输入的订阅地址并不是标准网址格式！"
			rm -rf /tmp/ssr_subscribe_file.txt >/dev/null 2>&1 &
			let DEL_SUBSCRIBE+=1
			sleep 1
			echo_date "退出订阅程序..."
			;;
		1|*)
			echo_date "下载订阅失败...请检查你的网络..."
			rm -rf /tmp/ssr_subscribe_file.txt >/dev/null 2>&1 &
			let DEL_SUBSCRIBE+=1
			sleep 1
			echo_date "退出订阅程序..."
			;;
		esac
	done
	remove_node_gap
	if [ "$DEL_SUBSCRIBE" == "0" ];then
		# 尝试删除去掉订阅链接对应的节点
		local_groups=`dbus list ssconf_basic_group_|cut -d "=" -f2|sort -u`
		if [ -f "/tmp/group_info.txt" ];then
			for local_group in $local_groups
			do
				MATCH=`</tmp/group_info.txt grep $local_group`
				if [ -z "$MATCH" ];then
					echo_date "==================================================================="
					echo_date 【$local_group】 节点已经不再订阅，将进行删除... 
					confs_nu=`dbus list ssconf |grep "$local_group"| cut -d "=" -f 1|cut -d "_" -f 4`
					for conf_nu in $confs_nu
					do
						dbus remove ssconf_basic_group_$conf_nu
						dbus remove ssconf_basic_koolgame_udp_$conf_nu
						dbus remove ssconf_basic_lbmode_$conf_nu
						dbus remove ssconf_basic_method_$conf_nu
						dbus remove ssconf_basic_mode_$conf_nu
						dbus remove ssconf_basic_name_$conf_nu
						dbus remove ssconf_basic_password_$conf_nu
						dbus remove ssconf_basic_port_$conf_nu
						dbus remove ssconf_basic_rss_obfs_$conf_nu
						dbus remove ssconf_basic_rss_obfs_param_$conf_nu
						dbus remove ssconf_basic_rss_protocol_$conf_nu
						dbus remove ssconf_basic_rss_protocol_param_$conf_nu
						dbus remove ssconf_basic_server_$conf_nu
						dbus remove ssconf_basic_server_ip_$conf_nu
						dbus remove ssconf_basic_ss_kcp_opts_$conf_nu
						dbus remove ssconf_basic_ss_kcp_support_$conf_nu
						dbus remove ssconf_basic_ss_sskcp_port_$conf_nu
						dbus remove ssconf_basic_ss_sskcp_server_$conf_nu
						dbus remove ssconf_basic_ss_ssudp_mtu_$conf_nu
						dbus remove ssconf_basic_ss_ssudp_port_$conf_nu
						dbus remove ssconf_basic_ss_ssudp_server_$conf_nu
						dbus remove ssconf_basic_ss_udp_opts_$conf_nu
						dbus remove ssconf_basic_ss_udp_support_$conf_nu
						dbus remove ssconf_basic_ss_v2ray_$conf_nu
						dbus remove ssconf_basic_ss_v2ray_plugin_$conf_nu
						dbus remove ssconf_basic_ss_v2ray_plugin_opts_$conf_nu
						dbus remove ssconf_basic_trojan_binary_$conf_nu
						dbus remove ssconf_basic_trojan_network_$conf_nu
						dbus remove ssconf_basic_trojan_sni_$conf_nu
						dbus remove ssconf_basic_fingerprint_$conf_nu
						dbus remove ssconf_basic_type_$conf_nu
						dbus remove ssconf_basic_use_kcp_$conf_nu
						dbus remove ssconf_basic_use_lb_$conf_nu
						dbus remove ssconf_basic_v2ray_alterid_$conf_nu
						dbus remove ssconf_basic_v2ray_headtype_kcp_$conf_nu
						dbus remove ssconf_basic_v2ray_headtype_tcp_$conf_nu
						dbus remove ssconf_basic_v2ray_json_$conf_nu
						dbus remove ssconf_basic_v2ray_mux_concurrency_$conf_nu
						dbus remove ssconf_basic_v2ray_mux_enable_$conf_nu
						dbus remove ssconf_basic_allowinsecure_$conf_nu
						dbus remove ssconf_basic_v2ray_network_$conf_nu
						dbus remove ssconf_basic_v2ray_network_flow_$conf_nu
						dbus remove ssconf_basic_v2ray_network_host_$conf_nu
						dbus remove ssconf_basic_v2ray_network_path_$conf_nu
						dbus remove ssconf_basic_v2ray_serviceName_$conf_nu						
						dbus remove ssconf_basic_v2ray_network_security_$conf_nu
						dbus remove ssconf_basic_v2ray_network_tlshost_$conf_nu
						dbus remove ssconf_basic_v2ray_protocol_$conf_nu
						dbus remove ssconf_basic_v2ray_security_$conf_nu
						dbus remove ssconf_basic_v2ray_use_json_$conf_nu
						dbus remove ssconf_basic_v2ray_uuid_$conf_nu
						dbus remove ssconf_basic_weight_$conf_nu
						dbus remove ssconf_basic_naive_protocol_$conf_nu
						dbus remove ssconf_basic_naive_user_$conf_nu
						dbus remove ssconf_basic_xray_publicKey_$conf_nu
						dbus remove ssconf_basic_xray_shortId_$conf_nu
					done
					# 删除不再订阅节点的group信息
					confs_nu_2=`dbus list ss_online_group_|grep "$local_group"| cut -d "=" -f 1|cut -d "_" -f 4`
					if [ -n "$confs_nu_2" ];then
						for conf_nu_2 in $confs_nu_2
						do
							dbus remove ss_online_group_$conf_nu_2
						done
					fi
					
					echo_date 删除完成完成！
					need_adjust=1
				fi
			done
			usleep 250000
			# 再次排序
			if [ "$need_adjust" == "1" ];then
				echo_date 因为进行了删除订阅节点操作，需要对节点顺序进行检查！
				remove_node_gap
			fi
		fi
	else
		echo_date "由于订阅过程有失败，本次不检测需要删除的订阅，以免误伤；下次成功订阅后再进行检测。"
	fi
	# 结束
	echo_date "-------------------------------------------------------------------"
	if [ "$SOCKS_FLAG" == "1" ];then
		ssrlocal=`ps | grep -w rss-local | grep -v "grep" | grep -w "23456" | awk '{print $1}'`
		if [ -n "$ssrlocal" ];then 
			echo_date 关闭因订阅临时开启的ssr-local进程:23456端口...
			kill $ssrlocal  >/dev/null 2>&1
		fi
	elif [ "$SOCKS_FLAG" == "2" ];then
		sslocal=`ps | grep -w ss-local | grep -v "grep" | grep -w "23456" | awk '{print $1}'`
		if [ -n "$sslocal" ];then 
			echo_date  关闭因订阅临时开启ss-local进程:23456端口...
			kill $sslocal  >/dev/null 2>&1
		fi
	fi
	usleep 250000
	echo_date "一点点清理工作..."
	rm -rf /tmp/ssr_subscribe_file.txt >/dev/null 2>&1
	rm -rf /tmp/ssr_subscribe_file_temp1.txt >/dev/null 2>&1
	rm -rf /tmp/all_localservers >/dev/null 2>&1
	rm -rf /tmp/all_onlineservers >/dev/null 2>&1
	rm -rf /tmp/all_group_info.txt >/dev/null 2>&1
	rm -rf /tmp/group_info.txt >/dev/null 2>&1
	echo_date "==================================================================="
	echo_date "所有订阅任务完成，请等待6秒，或者手动关闭本窗口！"
	echo_date "==================================================================="
}

add() {
	echo_date "==================================================================="
	usleep 250000
	echo_date 通过SS/SSR/v2ray/Trojan链接添加节点...
	rm -rf /tmp/ssr_subscribe_file.txt >/dev/null 2>&1
	rm -rf /tmp/ssr_subscribe_file_temp1.txt >/dev/null 2>&1
	rm -rf /tmp/all_localservers >/dev/null 2>&1
	rm -rf /tmp/all_onlineservers >/dev/null 2>&1
	rm -rf /tmp/all_group_info.txt >/dev/null 2>&1
	rm -rf /tmp/group_info.txt >/dev/null 2>&1
	#echo_date 添加链接为：`dbus get ss_base64_links`
	ssrlinks=`dbus get ss_base64_links | sed -e 's/$/\n/' -e '/^$/d'`
	
	for ssrlink in $ssrlinks
	do
		if [ -n "$ssrlink" ];then
			link=""
			decode_link=""

			NODE_FORMAT=$(echo $ssrlink | awk -F":" '{print $1}' | sed 's/-/_/')
			[ "$NODE_FORMAT" = "hy2" ] && NODE_FORMAT="hysteria2"
			#echo $NODE_FORMAT
			link=$(echo $ssrlink | cut -f3-  -d/ | urldecode | sed 's/[\r\n ]//g')
			#echo $link
			if [ -n "$NODE_FORMAT" ] && [ -n "$link" ]; then
				echo_date 检测到${NODE_FORMAT}链接...开始尝试解析...
				remarks='AddByLink'
				get_${NODE_FORMAT}_config $link 
				add_${NODE_FORMAT}_servers 1
			fi
		fi
		
	done
	dbus remove ss_base64_links	# not sure in this adjustment
	echo_date "==================================================================="
}

remove_all(){
	# 2 清除已有的ss节点配置
	echo_date 删除所有节点信息中！
	confs=`dbus list ssconf_basic_ | cut -d "=" -f 1`
	for conf in $confs
	do
	#	echo_date 移除$conf
		dbus remove $conf
	done
}

remove_online(){
	# 2 清除已有的ss节点配置
	echo_date 删除所有订阅节点信息中...自添加的节点不受影响！
	remove_nus=`dbus list ssconf_basic_|grep _group_ | cut -d "=" -f 1 | cut -d "_" -f4 | sort -n`
	for remove_nu in $remove_nus
	do
	#	echo_date 移除第 $remove_nu 节点...
		dbus remove ssconf_basic_group_$remove_nu
		dbus remove ssconf_basic_koolgame_udp_$remove_nu
		dbus remove ssconf_basic_lbmode_$remove_nu
		dbus remove ssconf_basic_method_$remove_nu
		dbus remove ssconf_basic_mode_$remove_nu
		dbus remove ssconf_basic_name_$remove_nu
		dbus remove ssconf_basic_password_$remove_nu
		dbus remove ssconf_basic_port_$remove_nu
		dbus remove ssconf_basic_rss_obfs_$remove_nu
		dbus remove ssconf_basic_rss_obfs_param_$remove_nu
		dbus remove ssconf_basic_rss_protocol_$remove_nu
		dbus remove ssconf_basic_rss_protocol_param_$remove_nu
		dbus remove ssconf_basic_server_$remove_nu
		dbus remove ssconf_basic_server_ip_$remove_nu
		dbus remove ssconf_basic_ss_kcp_opts_$remove_nu
		dbus remove ssconf_basic_ss_kcp_support_$remove_nu
		dbus remove ssconf_basic_ss_sskcp_port_$remove_nu
		dbus remove ssconf_basic_ss_sskcp_server_$remove_nu
		dbus remove ssconf_basic_ss_ssudp_mtu_$remove_nu
		dbus remove ssconf_basic_ss_ssudp_port_$remove_nu
		dbus remove ssconf_basic_ss_ssudp_server_$remove_nu
		dbus remove ssconf_basic_ss_udp_opts_$remove_nu
		dbus remove ssconf_basic_ss_udp_support_$remove_nu
		dbus remove ssconf_basic_ss_v2ray_$remove_nu
		dbus remove ssconf_basic_ss_v2ray_plugin_$remove_nu
		dbus remove ssconf_basic_ss_v2ray_plugin_opts_$remove_nu
		dbus remove ssconf_basic_trojan_binary_$remove_nu
		dbus remove ssconf_basic_trojan_network_$remove_nu
		dbus remove ssconf_basic_trojan_sni_$remove_nu
		dbus remove ssconf_basic_fingerprint_$remove_nu
		dbus remove ssconf_basic_type_$remove_nu
		dbus remove ssconf_basic_use_kcp_$remove_nu
		dbus remove ssconf_basic_use_lb_$remove_nu
		dbus remove ssconf_basic_v2ray_alterid_$remove_nu
		dbus remove ssconf_basic_v2ray_headtype_kcp_$remove_nu
		dbus remove ssconf_basic_v2ray_serviceName_$remove_nu
		dbus remove ssconf_basic_v2ray_headtype_tcp_$remove_nu
		dbus remove ssconf_basic_v2ray_json_$remove_nu
		dbus remove ssconf_basic_v2ray_mux_concurrency_$remove_nu
		dbus remove ssconf_basic_v2ray_mux_enable_$remove_nu
		dbus remove ssconf_basic_allowinsecure_$remove_nu
		dbus remove ssconf_basic_v2ray_network_$remove_nu
		dbus remove ssconf_basic_v2ray_network_flow_$remove_nu
		dbus remove ssconf_basic_v2ray_network_host_$remove_nu
		dbus remove ssconf_basic_v2ray_network_path_$remove_nu
		dbus remove ssconf_basic_v2ray_network_security_$remove_nu
		dbus remove ssconf_basic_v2ray_network_tlshost_$remove_nu
		dbus remove ssconf_basic_v2ray_protocol_$remove_nu
		dbus remove ssconf_basic_v2ray_security_$remove_nu
		dbus remove ssconf_basic_v2ray_use_json_$remove_nu
		dbus remove ssconf_basic_v2ray_uuid_$remove_nu
		dbus remove ssconf_basic_weight_$remove_nu
		dbus remove ssconf_basic_naive_protocol_$remove_nu
		dbus remove ssconf_basic_naive_user_$remove_nu
		dbus remove ssconf_basic_xray_publicKey_$remove_nu
		dbus remove ssconf_basic_xray_shortId_$remove_nu
	done
}

change_cru(){
	echo ==================================================================================================
	sed -i '/ssnodeupdate/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	if [ "$ss_basic_node_update" = "1" ];then
		if [ "$ss_basic_node_update_day" = "7" ];then
			cru a ssnodeupdate "2 $ss_basic_node_update_hr * * * /bin/sh /koolshare/scripts/ss_online_update.sh 3"
			echo_date "设置自动更新订阅服务在每天 $ss_basic_node_update_hr 点。"
		else
			cru a ssnodeupdate "2 $ss_basic_node_update_hr * * $ss_basic_node_update_day /bin/sh /koolshare/scripts/ss_online_update.sh 3"
			echo_date "设置自动更新订阅服务在星期 $ss_basic_node_update_day 的 $ss_basic_node_update_hr 点。"
		fi
	else
		echo_date "关闭自动更新订阅服务！"
		sed -i '/ssnodeupdate/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
}

case $ss_online_action in
0)
	# 删除所有节点
	set_lock
	detect
	remove_all
	unset_lock
	;;
1)
	# 删除所有订阅节点
	set_lock
	detect
	remove_online
	remove_node_gap
	unset_lock
	;;
2)
	# 保存订阅设置但是不订阅
	set_lock
	detect
	local_groups=`dbus list ssconf_basic_|grep group|cut -d "=" -f2|sort -u|wc -l`
	online_group=`dbus get ss_online_links|base64_decode|sed -e 's/$/\n/' -e '/^$/d'|wc -l`
	echo_date "保存订阅节点成功，现共有 $online_group 组订阅来源，当前节点列表内已经订阅了 $local_groups 组..."
	change_cru
	unset_lock
	;;
3)
	# 订阅节点
	set_lock
	detect
	echo_date "开始订阅"
	change_cru
	start_update
	unset_lock
	;;
4)
	# 通过链接添加ss:// ssr:// vmess:// trojan:// vless:// trojan-go:// hysteria2:// hy2:// anytls://
	set_lock
	detect
	add
	unset_lock
	;;
esac
