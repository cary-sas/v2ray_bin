#!/bin/sh

# shadowsocks script for AM380 merlin firmware
# by sadog (sadoneli@gmail.com) from koolshare.cn

source /koolshare/scripts/base.sh
eval `dbus export ssconf_basic`

case "$ssconf_basic_test_domain" in
	https://www.google.com.hk/)
		speed_test_url="https://dl.google.com/drive-file-stream/GoogleDriveSetup.exe"
	;;
	https://www.facebook.com/)
		speed_test_url="https://scontent-sjc3-1.xx.fbcdn.net/m1/v/t6/An-Y531FBt1_Dmjmdml0fAxWVznPEZ4KhVulHN4RqyLIqKI4Fldv1Q2EBkOSRtG8co5l0O9EVtYm894u1-w.zip?ccb=10-5&oh=00_AT9wS67x0noZvrW6rZWkwT2CNg5Pvk3kmpL9AWsVR8wdvg&oe=62944A47&_nc_sid=857daf"
	;;
	*)
		speed_test_url="http://cachefly.cachefly.net/100mb.test"
	;;
esac

agent="User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:32.0) Gecko/20100101 Firefox/32.0"

speed_test_curl(){
	sleep 3
	local Byte=`curl -A "$agent" "$speed_test_url" -o /dev/null --socks5-hostname 127.0.0.1:23458 --connect-timeout 5 --max-time 10 2>&1 | tr '\r' '\n' | awk '{print $NF}' | sed '1,3d;$d' | awk 'function max(x){i=0;for(val in x){if(i<=x[val]){i=x[val];}}return i;} {if ($1 ~ /k/) {a[$1]=$1*1024;next} else if ($1 ~ /M/) {a[$1]=$1*1024*1024;next} else {a[$1]=$1;next}} END{print max(a) }'`
	sleep 1	
	local KB=`awk -v sum=$Byte -v n=1024 'BEGIN{printf "%0.2f\n", sum/n}'`
	local MB=`awk -v sum=$KB -v n=1024 'BEGIN{printf "%0.2f\n", sum/n}'`
	Byte=${Byte%.*}
	KB=${KB%.*}
	result=`awk -v M=$MB -v k=$KB -v i=$Byte 'BEGIN { if(i>=1048576) print M"M"; else if(i<1024 && i>0) print i; else print k"K" }'`
	[ -z "$Byte" -o "$result" == "0K" ] && result="failed"
	dbus set ssconf_basic_webtest_$nu=$result
}
# flush previous test value in the table
webtest=`dbus list ssconf_basic_webtest_ | sort -n -t "_" -k 4|cut -d "=" -f 1`
if [ ! -z "$webtest" ];then
	for line in $webtest
	do
		dbus remove "$line"
	done
fi

get_function_switch() {
	case "$1" in
		1)
			echo "true"
		;;
		*)
			echo "false"
		;;
	esac
}

get_ws_header() {
	if [ -n "$1" ];then
		echo {\"Host\": \"$1\"}
	else
		echo "null"
	fi
}

get_h2_host() {
	if [ -n "$1" ];then
		echo [\"$1\"]
	else
		echo "null"
	fi
}

get_path(){
	if [ -n "$1" ];then
		echo \"$1\"
	else
		echo "null"
	fi
}

create_v2ray_json(){

rm -rf /tmp/tmp_v2ray.json

		local kcp="null"
		local tcp="null"
		local ws="null"
		local h2="null"
		local grpc="null"
		local tls="null"
		local xtls="null"
		local vless_flow=""

		# tcp和kcp下tlsSettings为null，ws和h2下tlsSettings
		[ -z "$(eval echo \$ssconf_basic_v2ray_mux_concurrency_$nu)" ] && local ssconf_basic_v2ray_mux_concurrency=8
		[ "$(eval echo \$ssconf_basic_v2ray_network_security_$nu)" == "none" ] && local ssconf_basic_v2ray_network_security=""
		
		if [ "$(eval echo \$ssconf_basic_v2ray_network_$nu)" == "ws" -o "$(eval echo \$ssconf_basic_v2ray_network_$nu)" == "h2" ] && [ -z "$(eval echo \$ssconf_basic_v2ray_network_tlshost_$nu)" ] && [ -n "$(eval echo \$ssconf_basic_v2ray_network_host_$nu)" ]; then
		 	local ssconf_basic_v2ray_network_tlshost_$nu="$(eval echo \$ssconf_basic_v2ray_network_host_$nu)"
		fi

		case "$(eval echo \$ssconf_basic_v2ray_network_security_$nu)" in
		tls)
			local tls="{
					\"allowInsecure\":  $(get_function_switch $(eval echo \$ssconf_basic_allowinsecure_$nu)),
					\"serverName\": \"$(eval echo \$ssconf_basic_v2ray_network_tlshost_$nu)\"
					}"
			;;
		xtls)
			local xtls="{
					\"allowInsecure\":  $(get_function_switch $(eval echo \$ssconf_basic_allowinsecure_$nu)),
					\"serverName\": \"$(eval echo \$ssconf_basic_v2ray_network_tlshost_$nu)\"
					}"
			local vless_flow="\"flow\": \"$(eval echo \$ssconf_basic_v2ray_network_flow_$nu)\","
			;;
		*)
			local tls="null"
			local xtls="null"
			;;
		esac
		#fi
		# incase multi-domain input
		if [ "$(eval echo \$ssconf_basic_v2ray_network_host_$nu | grep ",")" ]; then
			ssconf_basic_v2ray_network_host_$nu=$(eval echo \$ssconf_basic_v2ray_network_host_$nu | sed 's/,/", "/g')
		fi

		case "$(eval echo \$ssconf_basic_v2ray_network_$nu)" in
		tcp)
			if [ "$(eval echo \$ssconf_basic_v2ray_headtype_tcp_$nu)" == "http" ]; then
				local tcp="{
					\"connectionReuse\": true,
					\"header\": {
					\"type\": \"http\",
					\"request\": {
					\"version\": \"1.1\",
					\"method\": \"GET\",
					\"path\": [\"/\"],
					\"headers\": {
					\"Host\": [\"$(eval echo \$ssconf_basic_v2ray_network_host_$nu)\"],
					\"User-Agent\": [\"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.75 Safari/537.36\",\"Mozilla/5.0 (iPhone; CPU iPhone OS 10_0_2 like Mac OS X) AppleWebKit/601.1 (KHTML, like Gecko) CriOS/53.0.2785.109 Mobile/14A456 Safari/601.1.46\"],
					\"Accept-Encoding\": [\"gzip, deflate\"],
					\"Connection\": [\"keep-alive\"],
					\"Pragma\": \"no-cache\"
					}
					},
					\"response\": {
					\"version\": \"1.1\",
					\"status\": \"200\",
					\"reason\": \"OK\",
					\"headers\": {
					\"Content-Type\": [\"application/octet-stream\",\"video/mpeg\"],
					\"Transfer-Encoding\": [\"chunked\"],
					\"Connection\": [\"keep-alive\"],
					\"Pragma\": \"no-cache\"
					}
					}
					}
					}"
			else
				local tcp="null"
			fi
			;;
		kcp)
		local local_path=$(eval echo \$ssconf_basic_v2ray_network_path_$nu)
			local kcp="{
				\"mtu\": 1350,
				\"tti\": 50,
				\"uplinkCapacity\": 12,
				\"downlinkCapacity\": 100,
				\"congestion\": false,
				\"readBufferSize\": 2,
				\"writeBufferSize\": 2,
				\"seed\": "$local_path",
				\"header\": {
				\"type\": \"$(eval echo \$ssconf_basic_v2ray_headtype_kcp_$nu)\",
				\"request\": null,
				\"response\": null
				}
				}"
			[ -z "$local_path" ] && local kcp=$(echo $kcp |sed 's/"seed": "*, //')	
			;;
		ws)
		local local_path=$(eval echo \$ssconf_basic_v2ray_network_path_$nu)
		local local_header=$(eval echo \$ssconf_basic_v2ray_network_host_$nu)
			local ws="{
				\"connectionReuse\": true,
				\"path\": $(get_path $local_path),
				\"headers\": $(get_ws_header local_header)
				}"
			;;
		h2)
		local local_path=$(eval echo \$ssconf_basic_v2ray_network_path_$nu)
		local local_header=$(eval echo \$ssconf_basic_v2ray_network_host_$nu)
			local h2="{
				\"path\": $(get_path $local_path),
				\"host\": $(get_h2_host $local_header)
				}"
			;;
		grpc)
		local local_serviceName=$(eval echo \$ssconf_basic_v2ray_serviceName_$nu)
			local grpc="{
				\"multiMode\": true,
  				\"idle_timeout\": 13,
				\"serviceName\": $(get_path $local_serviceName) 
				}"
			;;	
		esac
		# log area
		cat >"/tmp/tmp_v2ray.json" <<-EOF
			{
			"log": {
				"access": "/dev/null",
				"error": "/tmp/v2ray_webtest_log.log",
				"loglevel": "error"
			},
		EOF
			# inbounds area (23458 for socks5)
			cat >>"/tmp/tmp_v2ray.json" <<-EOF
				"inbounds": [
					{
						"port": 23458,
						"listen": "0.0.0.0",
						"protocol": "socks",
						"settings": {
							"auth": "noauth",
							"udp": true,
							"ip": "127.0.0.1",
							"clients": null
						},
						"streamSettings": null
					},
					{
						"listen": "0.0.0.0",
						"port": 3335,
						"protocol": "dokodemo-door",
						"settings": {
							"network": "tcp,udp",
							"followRedirect": true
						}
					}
				],
			EOF
		# outbounds area
		if [ "$array13" == "vmess" ]; then
			cat >>"/tmp/tmp_v2ray.json" <<-EOF
				"outbounds": [
				  {
					"tag": "agentout",
					"protocol": "vmess",
					"settings": {
					  "vnext": [
						{
						  "address": "$(dbus get ssconf_basic_server_$nu)",
						  "port": $(eval echo \$ssconf_basic_port_$nu),
						  "users": [
							{
							  "id": "$(eval echo \$ssconf_basic_v2ray_uuid_$nu)",
							  "alterId": $(eval echo \$ssconf_basic_v2ray_alterid_$nu),
							  "security": "$(eval echo \$ssconf_basic_v2ray_security_$nu)"
							}
						  ]
						}
					  ],
					  "servers": null
					},
					"streamSettings": {
					  "network": "$(eval echo \$ssconf_basic_v2ray_network_$nu)",
					  "security": "$(eval echo \$ssconf_basic_v2ray_network_security_$nu)",
					  "tlsSettings": $tls,
					  "tcpSettings": $tcp,
					  "kcpSettings": $kcp,
					  "wsSettings": $ws,
					  "httpSettings": $h2,
					  "grpcSettings": $grpc
					},
					"mux": {
					  "enabled": $(get_function_switch $(eval echo \$ssconf_basic_v2ray_mux_enable_$nu)),
					  "concurrency": $ssconf_basic_v2ray_mux_concurrency
					}
				  }
				]
				}
			EOF
		elif [ "$array13" == "vless" ]; then
		  #vless
		  cat >>"/tmp/tmp_v2ray.json" <<-EOF
				"outbounds": [
				  {
					"tag": "agentout",
					"protocol": "vless",
					"settings": {
					  "vnext": [
						{
						  "address": "$(dbus get ssconf_basic_server_$nu)",
						  "port": $(eval echo \$ssconf_basic_port_$nu),
						  "users": [
							{
							  "id": "$(eval echo \$ssconf_basic_v2ray_uuid_$nu)",
							  "level": 1,
							  $vless_flow
							  "encryption": "none"
							}
						  ]
						}
					  ],
					  "servers": null
					},
					"streamSettings": {
					  "network": "$(eval echo \$ssconf_basic_v2ray_network_$nu)",
					  "security": "$(eval echo \$ssconf_basic_v2ray_network_security_$nu)",
					  "tlsSettings": $tls,
					  "xtlsSettings": $xtls,
					  "tcpSettings": $tcp,
					  "kcpSettings": $kcp,
					  "wsSettings": $ws,
					  "httpSettings": $h2,
					  "grpcSettings": $grpc
					},
					"mux": {
					  "enabled": $(get_function_switch $(eval echo \$ssconf_basic_v2ray_mux_enable_$nu)),
					  "concurrency": $ssconf_basic_v2ray_mux_concurrency
					}
				  }
				]
				}
			EOF
		fi
		
}

create_trojan_json(){
rm -rf /tmp/tmp_v2ray.json

		 #trojan
		 # inbounds area (23458 for socks5)  
		cat > /tmp/tmp_v2ray.json <<-EOF
		{
			"log": {
				"access": "/dev/null",
				"error": "/tmp/v2ray_webtest_log.log",
				"loglevel": "error"
			},
				"inbounds": [
					{
						"port": 23458,
						"listen": "0.0.0.0",
						"protocol": "socks",
						"settings": {
							"auth": "noauth",
							"udp": true,
							"ip": "127.0.0.1",
							"clients": null
						},
						"streamSettings": null
					},
					{
						"listen": "0.0.0.0",
						"port": 3335,
						"protocol": "dokodemo-door",
						"settings": {
							"network": "tcp,udp",
							"followRedirect": true
						}
					}
				],
			"outbounds": [
			  {
				"protocol": "trojan",
				"settings": {
				  "servers": [
					{
					  "address": "$array1",
					  "port": $array2,
					  "password": "$array3"
					}
				  ]
				},
				"streamSettings": {
				  "network": "tcp",
				  "security": "tls",
				  "tlsSettings": {
					"allowInsecure": $(get_function_switch $(eval echo \$ssconf_basic_allowinsecure_$nu)),  
                    "serverName": "$(eval echo \$ssconf_basic_trojan_sni_$nu)"
                }
				}
			  }
			]
		}
		EOF
}


create_trojango_json(){
	rm -rf /tmp/tmp_trojango.json
	rm -rf /tmp/tmp2_trojango.json
	if [ "$(eval echo \$ssconf_basic_trojan_network_$nu)" == "1" ]; then
		[ -n "$(eval echo \$ssconf_basic_v2ray_network_path_$nu)" ] && local ssconf_basic_v2ray_network_path=$(echo "/"$(eval echo \$ssconf_basic_v2ray_network_path_$nu)"" | sed 's,//,/,')
		[ -n "$(eval echo \$ssconf_basic_v2ray_network_host_$nu)" ] && local ssconf_basic_v2ray_network_host=$(eval echo \$ssconf_basic_v2ray_network_host_$nu)
		local ws="{ \"enabled\": true,
					\"path\":  \"$ssconf_basic_v2ray_network_path\",
					\"host\":  \"$ssconf_basic_v2ray_network_host\"
					}"
	else
		local ws="{ \"enabled\": false,
					\"path\":  \"\",
					\"host\":  \"\"
					}"
	fi
	[ -z "$(eval echo \$ssconf_basic_v2ray_mux_concurrency_$nu)" ] && local ssconf_basic_v2ray_mux_concurrency=8
		 #trojan go
		 # 3335 for nat  
		cat >"/tmp/tmp_trojango.json" <<-EOF
			{
				"run_type": "nat",
				"local_addr": "0.0.0.0",
				"local_port": 3335,
				"remote_addr": "$array1",
				"remote_port": $array2,
				"log_level": 5,
				"log_file": "/tmp/trojan-go_webtest_log.log",
				"password": [
				"$array3"
				],
				"disable_http_check": false,
				"udp_timeout": 60,
				"ssl": {
					"verify": true,
					"verify_hostname": true,
					"sni": "$(eval echo \$ssconf_basic_trojan_sni_$nu)",
					"alpn": [
					"http/1.1"
					],
					"session_ticket": true,
					"reuse_session": true
				},
				"tcp": {
					"no_delay": true,
					"keep_alive": true,
					"prefer_ipv4": true
				},
				"mux": {
					"enabled": $(get_function_switch $(eval echo \$ssconf_basic_v2ray_mux_enable_$nu)),
					"concurrency": $ssconf_basic_v2ray_mux_concurrency,
					"idle_timeout": 60
				},
				"websocket": $ws
				,
				"shadowsocks": {
					"enabled": false,
					"method": "AES-128-GCM",
					"password": ""
				}
			}
		EOF


		 #  23458 for socks5  
		cat >"/tmp/tmp2_trojango.json" <<-EOF
			{
				"run_type": "client",
				"local_addr": "127.0.0.1",
				"local_port": 23458,
				"remote_addr": "$array1",
				"remote_port": $array2,
				"log_level": 5,
				"log_file": "/tmp/trojan-go_webtest_log.log",
				"password": [
				"$array3"
				],
				"disable_http_check": false,
				"udp_timeout": 60,
				"ssl": {
					"verify": true,
					"verify_hostname": true,
					"sni": "$(eval echo \$ssconf_basic_trojan_sni_$nu)",
					"alpn": [
					"http/1.1"
					],
					"session_ticket": true,
					"reuse_session": true
				},
				"tcp": {
					"no_delay": true,
					"keep_alive": true,
					"prefer_ipv4": true
				},
				"mux": {
					"enabled": $(get_function_switch $(eval echo \$ssconf_basic_v2ray_mux_enable_$nu)),
					"concurrency": $ssconf_basic_v2ray_mux_concurrency,
					"idle_timeout": 60
				},
				"websocket": $ws
				,
				"shadowsocks": {
					"enabled": false,
					"method": "AES-128-GCM",
					"password": ""
				}
			}
		EOF
	
}

start_webtest(){
	array1=`dbus get ssconf_basic_server_$nu`
	array2=`dbus get ssconf_basic_port_$nu`
	array3=`dbus get ssconf_basic_password_$nu|base64_decode`
	array4=`dbus get ssconf_basic_method_$nu`
	array5=`dbus get ssconf_basic_use_rss_$nu`
	#array6=`dbus get ssconf_basic_onetime_auth_$nu`
	array7=`dbus get ssconf_basic_rss_protocol_$nu`
	array8=`dbus get ssconf_basic_rss_obfs_$nu`
	array9=`dbus get ssconf_basic_ss_v2ray_plugin_$nu`
	array10=`dbus get ssconf_basic_ss_v2ray_plugin_opts_$nu`
	array11=`dbus get ssconf_basic_mode_$nu`
	array12=`dbus get ssconf_basic_type_$nu`	
	array13=`dbus get ssconf_basic_v2ray_protocol_$nu`
	array14=`dbus get ssconf_basic_trojan_binary_$nu`

	if [ "$array10" != "" ];then
		if [ "$array9" == "1" ];then
			ARG_V2RAY_PLUGIN="--plugin v2ray-plugin --plugin-opts $array10"
		elif [ "$array9" == "2" ];then
			ARG_V2RAY_PLUGIN="--plugin obfs-local --plugin-opts $array10"
		else
			ARG_V2RAY_PLUGIN=""
		fi
	fi
	
	if [ "$array11" == "1" ] || [ "$array11" == "2" ] || [ "$array11" == "3" ] || [ "$array11" == "5" ];then
       # Resolve domain name to IP for SS and SSR
		if [ "$array12" == "1" ] || [ "$array12" == "0" ];then   
			IFIP=`echo $array1|grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:"`
			if [ -z "$IFIP" ];then
				server_ip=`resolveip -4 -t 2 "$array1" |awk 'NR==1{print}'`
			fi 
		fi

		if [ "$array12" == "1" ];then   #ssr
			cat > /tmp/tmp_ss.json <<-EOF
			{
			    "server":"$server_ip",
			    "server_port":$array2,
			    "local_port":23458,
			    "password":"$array3",
			    "timeout":600,
			    "protocol":"$array7",
			    "obfs":"$array8",
			    "obfs_param":"",
			    "method":"$array4"
			}
		EOF
			rss-local -b 0.0.0.0 -l 23458 -c /tmp/tmp_ss.json -u -f /var/run/sslocal2.pid >/dev/null 2>&1
			# result=`curl -o /dev/null -s -w %{time_connect}:%{time_starttransfer}:%{time_total}:%{speed_download} --socks5-hostname 127.0.0.1:23458 https://www.google.com/`
			speed_test_curl
			kill -9 `ps|grep -w rss-local|grep 23458|awk '{print $1}'` >/dev/null 2>&1
			rm -rf /tmp/tmp_ss.json
			
		elif [ "$array12" == "0" ];then   #ss
			ss-local -b 0.0.0.0 -l 23458 -s $server_ip -p $array2 -k $array3 -m $array4 -u $ARG_V2RAY_PLUGIN -f /var/run/sslocal3.pid >/dev/null 2>&1
			speed_test_curl
			ss_local_pid=$(ps|grep -w ss-local|grep 23458|awk '{print $1}')			
			if [ -n "$ARG_V2RAY_PLUGIN" ];then 
				v2ray_plugin_pid=$(top -b -n 1 | grep -E 'v2ray-plugin|obfs-local' | awk -v ss_local_pid="$ss_local_pid"  '$2 == ss_local_pid {print $1}')
				kill -9 $v2ray_plugin_pid  >/dev/null 2>&1
			fi	
			kill -9 $ss_local_pid >/dev/null 2>&1

		elif [ "$array12" == "3" ];then   #v2ray
			create_v2ray_json 
			xray run -config=/tmp/tmp_v2ray.json >/dev/null 2>&1 &
			speed_test_curl
			kill -9 `ps|grep xray|grep 'tmp_v2ray'|awk '{print $1}'` >/dev/null 2>&1	
			rm -rf /tmp/tmp_v2ray.json /tmp/v2ray_webtest_log.log
			
		elif [ "$array12" == "4" -a "$array14" == "Trojan" ];then   #trojan
			create_trojan_json 
			xray run -config=/tmp/tmp_v2ray.json >/dev/null 2>&1 &
			speed_test_curl
			kill -9 `ps|grep xray|grep 'tmp_v2ray'|awk '{print $1}'` >/dev/null 2>&1	
			rm -rf /tmp/tmp_v2ray.json	/tmp/v2ray_webtest_log.log

		elif [ "$array12" == "4" -a "$array14" == "Trojan-Go" ];then   #trojan go
			create_trojango_json 
			trojan-go -config=/tmp/tmp_trojango.json >/dev/null 2>&1 &
			trojan-go -config=/tmp/tmp2_trojango.json >/dev/null 2>&1 &
			speed_test_curl
			kill -9 `ps|grep 'trojan-go' | grep 'tmp2_trojango'|awk '{print $1}'` >/dev/null 2>&1
			kill -9 `ps|grep 'trojan-go' | grep 'tmp_trojango'|awk '{print $1}'` >/dev/null 2>&1	
			rm -rf /tmp/tmp_trojango.json /tmp/tmp2_trojango.json /tmp/trojan-go_webtest_log.log
		fi

	else
		dbus set ssconf_basic_webtest_$nu="failed"
	fi
}

# start testing
if [ "$ssconf_basic_test_node" != "0" ];then
	nu="$ssconf_basic_test_node"
	start_webtest
else
	server_nu=`dbus list ssconf_basic_server | sort -n -t "_" -k 4|cut -d "=" -f 1|cut -d "_" -f 4`
	for nu in $server_nu
	do
		start_webtest
	done
fi
