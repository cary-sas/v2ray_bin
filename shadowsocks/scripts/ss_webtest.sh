#!/bin/sh

# shadowsocks script for AM380 merlin firmware
# by sadog (sadoneli@gmail.com) from koolshare.cn

source /koolshare/scripts/base.sh
eval `dbus export ssconf_basic`
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'

case "$ssconf_basic_test_domain" in
	https://www.google.com.hk/)
		latency_test_url="https://www.google.com/generate_204"
	;;
	https://www.gstatic.com/generate_204)
		latency_test_url="https://www.gstatic.com/generate_204"
	;;
	*)
		latency_test_url="https://www.google.com/generate_204"
	;;
esac

agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:32.0) Gecko/20100101 Firefox/32.0"

speed_test_curl(){
	sleep 1

	local proxy_host="127.0.0.1"
	local proxy_port="23458"
	local warm_timeout=5
	local score_timeout=5
	local retry_timeout=5

	local raw=""
	local score1_ms=""
	local score2_ms=""
	local score3_ms=""
	local best_ms=""
	local result=""
	local has_timeout=0

	curl_probe() {
		local tag="$1"
		local timeout_sec="$2"

		curl -k -A "$agent" -I "$latency_test_url" -o /dev/null \
			--socks5-hostname ${proxy_host}:${proxy_port} \
			--connect-timeout "$timeout_sec" \
			--max-time "$timeout_sec" \
			--write-out "${tag}|%{exitcode}|%{http_code}|%{time_total}\n" \
			-s 2>/dev/null
	}

	parse_probe_ms() {
		local line="$1"
		local exit_code=""
		local http_code=""
		local time_total=""

		exit_code=$(echo "$line" | awk -F'|' '{print $2}')
		http_code=$(echo "$line" | awk -F'|' '{print $3}')
		time_total=$(echo "$line" | awk -F'|' '{print $4}')

		if [ "$exit_code" = "28" ]; then
			echo "timeout"
			return 0
		fi

		if [ "$exit_code" = "0" ] && [ -n "$time_total" ] && { [ "$http_code" = "200" ] || [ "$http_code" = "204" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; }; then
			awk -v t="$time_total" 'BEGIN{
				ms = int(t * 1000 + 0.5);
				if (ms > 5000) print "timeout";
				else print ms;
			}'
			return 0
		fi

		echo ""
		return 1
	}

	pick_better_ms() {
		local a="$1"
		local b="$2"

		if [ -z "$a" ]; then
			echo "$b"
			return 0
		fi
		if [ -z "$b" ]; then
			echo "$a"
			return 0
		fi
		if [ "$a" = "timeout" ]; then
			echo "$b"
			return 0
		fi
		if [ "$b" = "timeout" ]; then
			echo "$a"
			return 0
		fi
		if [ "$a" -le "$b" ] 2>/dev/null; then
			echo "$a"
		else
			echo "$b"
		fi
	}

	score_latency() {
		local ms="$1"
		if [ -z "$ms" ] || [ "$ms" = "failed" ] || [ "$ms" = "timeout" ]; then
			echo ""
		elif [ "$ms" -le 400 ] 2>/dev/null; then
			echo "S"
		elif [ "$ms" -le 700 ] 2>/dev/null; then
			echo "A"
		elif [ "$ms" -le 1000 ] 2>/dev/null; then
			echo "B"
		elif [ "$ms" -le 1500 ] 2>/dev/null; then
			echo "C"
		else
			echo "D"
		fi
	}

	# 1) warmup：只预热，不计分
	raw=$(curl_probe "warm" "$warm_timeout")
	if [ "$(parse_probe_ms "$raw")" = "timeout" ]; then
		has_timeout=1
	fi

	# 2) score1
	raw=$(curl_probe "score1" "$score_timeout")
	score1_ms=$(parse_probe_ms "$raw")
	if [ "$score1_ms" = "timeout" ]; then
		has_timeout=1
	fi

	# 3) score2
	raw=$(curl_probe "score2" "$retry_timeout")
	score2_ms=$(parse_probe_ms "$raw")
	if [ "$score2_ms" = "timeout" ]; then
		has_timeout=1
	fi

	# 4) score3（新增）
	raw=$(curl_probe "score3" "$retry_timeout")
	score3_ms=$(parse_probe_ms "$raw")
	if [ "$score3_ms" = "timeout" ]; then
		has_timeout=1
	fi

	# 5) 最终结果：只看后两次的最优值，更接近稳定使用状态
	best_ms=$(pick_better_ms "$score2_ms" "$score3_ms")

	# 如果后两次都没值，就回退到 score1
	[ -z "$best_ms" ] && best_ms="$score1_ms"

	if [ -n "$best_ms" ]; then
		if [ "$best_ms" = "timeout" ]; then
			result="timeout"
		else
			local grade=""
			grade=$(score_latency "$best_ms")
			if [ -n "$grade" ]; then
				result="${best_ms} ms [${grade}]"
			else
				result="${best_ms} ms"
			fi
		fi
	else
		if [ "$has_timeout" = "1" ]; then
			result="timeout"
		else
			result="failed"
		fi
	fi

	dbus set ssconf_basic_webtest_$nu="$result"
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

get_fingerprint(){
	if [ -n "$1" ];then
		echo \"$1\"
	else
		echo "null"
	fi
}
create_v2ray_json(){

	rm -f /tmp/tmp_v2ray.json
	rm -f /tmp/tmp_user.json
	rm -f /tmp/tmp_v2ray.final.json

	# =========================================================
	# 1) 优先处理：使用自定义 JSON 配置的节点
	# =========================================================
		local use_json=$(eval echo \$ssconf_basic_v2ray_use_json_$nu)
	if [ "$use_json" = "1" ]; then
		echo_date "webtest: 使用自定义 JSON 节点..."

		local RAW_JSON=$(eval echo \$ssconf_basic_v2ray_json_$nu | base64_decode)
		echo "$RAW_JSON" > /tmp/tmp_user.json

		# 兼容 outbound / outbounds
		OUTBOUNDS_ARR=$(jq -c '
			if (.outbounds? // null) != null then
				.outbounds
			elif (.outbound? // null) != null then
				[ .outbound ]
			else
				[]
			end
		' /tmp/tmp_user.json)

		# 是否为 xagg 聚合节点
		IS_XAGG=$(echo "$OUTBOUNDS_ARR" | jq -r '
			any(.[]; ((.tag // "") | startswith("xagg_")))
		')

		if [ "$IS_XAGG" = "true" ]; then
			echo_date "webtest: 检测到 xagg 聚合节点，补全 balancer / routing / observatory ..."

			TAGS=$(echo "$OUTBOUNDS_ARR" | jq -c '
												[ .[]
													| select((.tag // "") | startswith("xagg_"))
													| select(.tag != "xagg_meta")
													| .tag
												]
												')

			jq -nc \
				--argjson outbounds "$OUTBOUNDS_ARR" \
				--argjson tags "$TAGS" '
				{
				  "log": {
				    "access": "/dev/null",
				    "error": "/tmp/v2ray_webtest_log.log",
				    "loglevel": "debug"
				  },
				  "inbounds": [
				    {
				      "tag": "webtest-socks",
				      "port": 23458,
				      "listen": "0.0.0.0",
				      "protocol": "socks",
				      "settings": {
				        "auth": "noauth",
				        "udp": false,
				        "ip": "127.0.0.1",
				        "clients": null
				      }
				    }
				  ],
				  "outbounds": $outbounds,
				  "routing": {
				    "domainStrategy": "AsIs",
				    "balancers": [
				      {
				        "tag": "balancer-main",
				        "selector": $tags,
				        "strategy": {
				          "type": "leastPing"
				        }
				      }
				    ],
				    "rules": [
				      {
				        "type": "field",
				        "inboundTag": ["webtest-socks"],
				        "balancerTag": "balancer-main"
				      }
				    ]
				  },
				  "observatory": {
				    "subjectSelector": $tags,
				    "probeURL": "https://www.gstatic.com/generate_204",
				    "probeInterval": "3s"
				  }
				}
			' > /tmp/tmp_v2ray.json
		else
			echo_date "webtest: 普通 JSON 节点，原样使用 + 追加 23458 socks inbound ..."

			jq '
				.inbounds = (
					[
						{
							"tag": "webtest-socks",
							"port": 23458,
							"listen": "0.0.0.0",
							"protocol": "socks",
							"settings": {
								"auth": "noauth",
								"udp": false,
								"ip": "127.0.0.1",
								"clients": null
							}
						}
					] + (.inbounds // [])
				)
			' /tmp/tmp_user.json > /tmp/tmp_v2ray.json
		fi

		rm -f /tmp/tmp_user.json
		return 0
	fi

	# =========================================================
	# 2) 非 JSON 节点：按原插件字段动态生成
	# =========================================================
	local kcp="null"
	local tcp="null"
	local ws="null"
	local h2="null"
	local grpc="null"
	local tls="null"
	local reality="null"
	local vless_flow=""

	# tcp和kcp下tlsSettings为null，ws和h2下tlsSettings
	[ "$(eval echo \$ssconf_basic_v2ray_network_security_$nu)" = "none" ] && local ssconf_basic_v2ray_network_security=""

	if [ "$(eval echo \$ssconf_basic_v2ray_network_$nu)" = "ws" -o "$(eval echo \$ssconf_basic_v2ray_network_$nu)" = "h2" ] && \
	   [ -z "$(eval echo \$ssconf_basic_v2ray_network_tlshost_$nu)" ] && \
	   [ -n "$(eval echo \$ssconf_basic_v2ray_network_host_$nu)" ]; then
		local ssconf_basic_v2ray_network_tlshost_$nu="$(eval echo \$ssconf_basic_v2ray_network_host_$nu)"
	fi

	local local_fingerprint=$(eval echo \$ssconf_basic_fingerprint_$nu)

	case "$(eval echo \$ssconf_basic_v2ray_network_security_$nu)" in
	tls)
		local tls="{
				\"allowInsecure\": $(get_function_switch $(eval echo \$ssconf_basic_allowinsecure_$nu)),
				\"fingerprint\": $(get_fingerprint $local_fingerprint),
				\"serverName\": \"$(eval echo \$ssconf_basic_v2ray_network_tlshost_$nu)\"
				}"
		[ "$(eval echo \$ssconf_basic_v2ray_network_flow_$nu)" != "none" -a \
		  "$(eval echo \$ssconf_basic_v2ray_network_flow_$nu)" != "" ] && \
		  local vless_flow="\"flow\": \"$(eval echo \$ssconf_basic_v2ray_network_flow_$nu)\"," || \
		  local vless_flow=""
		;;
	reality)
		local reality="{
				\"serverName\": \"$(eval echo \$ssconf_basic_v2ray_network_tlshost_$nu)\",
				\"fingerprint\": $(get_fingerprint $local_fingerprint),
				\"publicKey\": \"$(eval echo \$ssconf_basic_xray_publicKey_$nu)\",
				\"shortId\": \"$(eval echo \$ssconf_basic_xray_shortId_$nu)\",
				\"spiderX\": \"\"
				}"
		local vless_flow="\"flow\": \"$(eval echo \$ssconf_basic_v2ray_network_flow_$nu)\","
		;;
	*)
		local tls="null"
		local reality="null"
		;;
	esac

	# multi-domain host
	if [ "$(eval echo \$ssconf_basic_v2ray_network_host_$nu | grep ",")" ]; then
		ssconf_basic_v2ray_network_host_$nu=$(eval echo \$ssconf_basic_v2ray_network_host_$nu | sed 's/,/", "/g')
	fi

	case "$(eval echo \$ssconf_basic_v2ray_network_$nu)" in
	tcp)
		if [ "$(eval echo \$ssconf_basic_v2ray_headtype_tcp_$nu)" = "http" ]; then
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
							\"User-Agent\": [
								\"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.75 Safari/537.36\",
								\"Mozilla/5.0 (iPhone; CPU iPhone OS 10_0_2 like Mac OS X) AppleWebKit/601.1 (KHTML, like Gecko) CriOS/53.0.2785.109 Mobile/14A456 Safari/601.1.46\"
							],
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
							\"Content-Type\": [\"application/octet-stream\", \"video/mpeg\"],
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
			\"seed\": \"$local_path\",
			\"header\": {
				\"type\": \"$(eval echo \$ssconf_basic_v2ray_headtype_kcp_$nu)\",
				\"request\": null,
				\"response\": null
			}
		}"
		[ -z "$local_path" ] && local kcp=$(echo $kcp | sed 's/"seed": "*, //')
		;;
	ws)
		local local_path=$(eval echo \$ssconf_basic_v2ray_network_path_$nu)
		local local_header=$(eval echo \$ssconf_basic_v2ray_network_host_$nu)
		local ws="{
			\"connectionReuse\": true,
			\"fingerprint\": $(get_fingerprint $local_fingerprint),
			\"path\": $(get_path $local_path),
			\"headers\": $(get_ws_header $local_header)
		}"
		;;
	h2)
		local local_path=$(eval echo \$ssconf_basic_v2ray_network_path_$nu)
		local local_header=$(eval echo \$ssconf_basic_v2ray_network_host_$nu)
		local h2="{
			\"fingerprint\": $(get_fingerprint $local_fingerprint),
			\"path\": $(get_path $local_path),
			\"host\": $(get_h2_host $local_header)
		}"
		;;
	grpc)
		local local_serviceName=$(eval echo \$ssconf_basic_v2ray_serviceName_$nu)
		local grpc="{
			\"multiMode\": true,
			\"idle_timeout\": 13,
			\"fingerprint\": $(get_fingerprint $local_fingerprint),
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
				"tag": "socks-in",
				"port": 23458,
				"listen": "0.0.0.0",
				"protocol": "socks",
				"settings": {
					"auth": "noauth",
					"udp": false,
					"ip": "127.0.0.1",
					"clients": null
				}
			}
		],
	EOF

	# outbounds area
	if [ "$array13" = "vmess" ]; then
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
					"concurrency": 8
				}
			}
		]
		}
		EOF

	elif [ "$array13" = "vless" ]; then
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
					"realitySettings": $reality,
					"tcpSettings": $tcp,
					"kcpSettings": $kcp,
					"wsSettings": $ws,
					"httpSettings": $h2,
					"grpcSettings": $grpc
				},
				"mux": {
					"enabled": $(get_function_switch $(eval echo \$ssconf_basic_v2ray_mux_enable_$nu)),
					"concurrency": 8
				}
			}
		]
		}
		EOF
	fi
}

create_trojan_json(){
rm -f /tmp/tmp_v2ray.json

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
							"udp": false,
							"ip": "127.0.0.1",
							"clients": null
						},
						"streamSettings": null
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
	rm -f /tmp/tmp_v2ray.json

	local trojan_sni="$(eval echo \$ssconf_basic_trojan_sni_$nu)"
	local trojango_network="tcp"
	local ws_settings="null"
	local mux_concurrency="$(eval echo \$ssconf_basic_v2ray_mux_concurrency_$nu)"

	[ -z "$mux_concurrency" ] && mux_concurrency=8
	[ -z "$trojan_sni" ] && [ -n "$(eval echo \$ssconf_basic_v2ray_network_host_$nu)" ] && trojan_sni="$(eval echo \$ssconf_basic_v2ray_network_host_$nu)"

	if [ "$(eval echo \$ssconf_basic_trojan_network_$nu)" == "1" ]; then
		[ -n "$(eval echo \$ssconf_basic_v2ray_network_path_$nu)" ] && local ssconf_basic_v2ray_network_path=$(echo "/"$(eval echo \$ssconf_basic_v2ray_network_path_$nu)"" | sed 's,//,/,')
		[ -n "$(eval echo \$ssconf_basic_v2ray_network_host_$nu)" ] && local ssconf_basic_v2ray_network_host=$(eval echo \$ssconf_basic_v2ray_network_host_$nu)
		trojango_network="ws"
		ws_settings="{\"path\": \"$ssconf_basic_v2ray_network_path\", \"headers\": {\"Host\": \"$ssconf_basic_v2ray_network_host\"}}"
	fi

	cat >"/tmp/tmp_v2ray.json" <<-EOF
		{
			"log": {
				"access": "/dev/null",
				"error": "/tmp/v2ray_webtest_log.log",
				"loglevel": "error"
			},
			"inbounds": [
				{
					"tag": "webtest-socks",
					"port": 23458,
					"listen": "0.0.0.0",
					"protocol": "socks",
					"settings": {
						"auth": "noauth",
						"udp": false,
						"ip": "127.0.0.1",
						"clients": null
					},
					"streamSettings": null
				}
			],
			"outbounds": [
				{
					"tag": "agentout",
					"protocol": "trojan-go",
					"settings": {
						"trojanGoMux": {
							"enabled": $(get_function_switch $(eval echo \$ssconf_basic_v2ray_mux_enable_$nu)),
							"concurrency": $mux_concurrency,
							"idle_timeout": 60
						},
						"servers": [
							{
								"address": "$array1",
								"port": $array2,
								"password": "$array3"
							}
						]
					},
					"streamSettings": {
						"network": "$trojango_network",
						"security": "tls",
						"tlsSettings": {
							"allowInsecure": $(get_function_switch $(eval echo \$ssconf_basic_allowinsecure_$nu)),
							"serverName": "$trojan_sni",
							"alpn": ["http/1.1"],
							"fingerprint": $(get_fingerprint $(eval echo \$ssconf_basic_fingerprint_$nu))
						},
						"wsSettings": $ws_settings
					},
					"mux": {
						"enabled": false,
						"concurrency": 1
					}
				}
			]
		}
	EOF
}

create_naive_json(){
	rm -f /tmp/tmp2_naive.json
		 #NaiveProxy

		 #  23458 for socks
		cat >/tmp/tmp2_naive.json <<-EOF
			{
			"listen": "socks://127.0.0.1:23458",
			"proxy": "${array15}://${array16}:${array3}@${array1}:$array2"
			}
		EOF
}

create_hy2_json(){
	rm -f /tmp/tmp_hysteria.json /tmp/tmp_hysteria_global.json /tmp/tmp_hysteria.final.json

	cat >/tmp/tmp_hysteria.json <<-EOF
				{
				"server": "${array1}:${array2}",
				"auth": "${array3}",
				"tls": {
					"sni": "$(eval echo \$ssconf_basic_trojan_sni_$nu)",
					"insecure": $(get_function_switch $(eval echo \$ssconf_basic_allowinsecure_$nu))
				},
				"fastOpen": true,
				"lazy": true,
				"socks5": {
					"listen": "127.0.0.1:23458"
				}
			}
	EOF

	hy2_global_json="$(dbus get ss_basic_hy2_global_json)"
	if [ -n "$hy2_global_json" ]; then
		echo "$hy2_global_json" | base64_decode > /tmp/tmp_hysteria_global.json
		if jq -e 'type == "object" and length > 0 and (length == ([keys_unsorted[] | select(. == "obfs" or . == "congestion" or . == "bandwidth")] | length))' /tmp/tmp_hysteria_global.json >/dev/null 2>&1; then
			jq -s '.[0] * .[1]' /tmp/tmp_hysteria.json /tmp/tmp_hysteria_global.json > /tmp/tmp_hysteria.final.json && mv /tmp/tmp_hysteria.final.json /tmp/tmp_hysteria.json
			echo_date "webtest: Hysteria2 global config merged."
		else
			echo_date "webtest: Hysteria2 global config invalid, skipped."
		fi
		rm -f /tmp/tmp_hysteria_global.json /tmp/tmp_hysteria.final.json
	fi
}

create_ss2022_json(){
	rm -f /tmp/tmp_v2ray.json
		 #Shadowsocks 2022 
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
							"udp": false,
							"ip": "127.0.0.1",
							"clients": null
						},
						"streamSettings": null
					}
				],
			"outbounds": [
			  {
				"protocol": "shadowsocks",
				"settings": {
				  "servers": [
					{
					  "address": "$array1",
					  "port": $array2,
					  "method": "$array4",
					  "password": "$array3"
					}
				  ]
				}
			  }
			]
		}
		EOF
}

start_webtest(){
	array1=`dbus get ssconf_basic_server_$nu`
	array2=`dbus get ssconf_basic_port_$nu`
	array3=`dbus get ssconf_basic_password_$nu|base64_decode`
	array4=`dbus get ssconf_basic_method_$nu`
	array5=`dbus get ssconf_basic_use_rss_$nu`
	array6=`dbus get ssconf_basic_rss_obfs_param_$nu`
	array7=`dbus get ssconf_basic_rss_protocol_$nu`
	array8=`dbus get ssconf_basic_rss_obfs_$nu`
	array9=`dbus get ssconf_basic_ss_v2ray_plugin_$nu`
	array10=`dbus get ssconf_basic_ss_v2ray_plugin_opts_$nu`
	array11=`dbus get ssconf_basic_mode_$nu`
	array12=`dbus get ssconf_basic_type_$nu`	
	array13=`dbus get ssconf_basic_v2ray_protocol_$nu`
	array14=`dbus get ssconf_basic_trojan_binary_$nu`
	array15=`dbus get ssconf_basic_naive_protocol_$nu`
	array16=`dbus get ssconf_basic_naive_user_$nu`


	if [ "$array12" == "0" ];then
		case $array4 in
			2022-blake3-aes-128-gcm|2022-blake3-aes-256-gcm|2022-blake3-chacha20-poly1305|none) SS2022_webtest="Y";;
			*)             SS2022_webtest="N";;
		esac
	fi
	[ "$SS2022_webtest" == "Y" ] && array12="3"

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
			    "obfs_param":"$array6",
			    "method":"$array4"
			}
		EOF
			rss-local -b 0.0.0.0 -l 23458 -c /tmp/tmp_ss.json -f /var/run/sslocal2.pid >/dev/null 2>&1
			# result=`curl -o /dev/null -s -w %{time_connect}:%{time_starttransfer}:%{time_total}:%{speed_download} --socks5-hostname 127.0.0.1:23458 https://www.google.com/`
			speed_test_curl
			kill -9 `ps|grep -w rss-local|grep 23458|awk '{print $1}'` >/dev/null 2>&1
			rm -f /tmp/tmp_ss.json
			
		elif [ "$array12" == "0" ];then   #ss
			ss-local -b 0.0.0.0 -l 23458 -s $server_ip -p $array2 -k $array3 -m $array4 $ARG_V2RAY_PLUGIN -f /var/run/sslocal3.pid >/dev/null 2>&1
			speed_test_curl
			ss_local_pid=$(ps|grep -w ss-local|grep 23458|awk '{print $1}')			
			if [ -n "$ARG_V2RAY_PLUGIN" ];then 
				v2ray_plugin_pid=$(top -b -n 1 | grep -E 'v2ray-plugin|obfs-local' | awk -v ss_local_pid="$ss_local_pid"  '$2 == ss_local_pid {print $1}')
				kill -9 $v2ray_plugin_pid  >/dev/null 2>&1
			fi	
			kill -9 $ss_local_pid >/dev/null 2>&1

		elif [ "$array12" == "3" ] && [ "$SS2022_webtest" != "Y" ];then   #v2ray
			create_v2ray_json 
			xray run -config=/tmp/tmp_v2ray.json >/dev/null 2>&1 &
			local i=0
			while [ "$i" -lt 20 ]
			do
				netstat -nl 2>/dev/null | grep -q '[:.]23458[[:space:]]' && break
				sleep 1
				i=$((i + 1))
			done

			# xagg observatory 需要额外时间
			if jq -e '.observatory? // empty' /tmp/tmp_v2ray.json >/dev/null 2>&1; then
				sleep 5
			fi
			speed_test_curl
			kill -9 `ps|grep 'xray' |grep 'tmp_v2ray'|awk '{print $1}'` >/dev/null 2>&1
			rm -f /tmp/tmp_v2ray.json /tmp/v2ray_webtest_log.log

		elif [ "$array12" == "3" ] && [ "$SS2022_webtest" == "Y" ];then   #ShadowSocks 2022
			create_ss2022_json 
			xray run -config=/tmp/tmp_v2ray.json >/dev/null 2>&1 &
			speed_test_curl
			kill -9 `ps|grep xray|grep 'tmp_v2ray'|awk '{print $1}'` >/dev/null 2>&1	
			rm -f /tmp/tmp_v2ray.json /tmp/v2ray_webtest_log.log
	
		elif [ "$array12" == "4" -a "$array14" == "Trojan" ];then   #trojan
			create_trojan_json 
			xray run -config=/tmp/tmp_v2ray.json >/dev/null 2>&1 &
			speed_test_curl
			kill -9 `ps|grep xray|grep 'tmp_v2ray'|awk '{print $1}'` >/dev/null 2>&1	
			rm -f /tmp/tmp_v2ray.json	/tmp/v2ray_webtest_log.log

		elif [ "$array12" == "4" -a "$array14" == "Trojan-Go" ];then   #trojan go
			create_trojango_json 
			xray run -config=/tmp/tmp_v2ray.json >/dev/null 2>&1 &
			local i=0
			while [ "$i" -lt 20 ]
			do
				netstat -nl 2>/dev/null | grep -q '[:.]23458[[:space:]]' && break
				sleep 1
				i=$((i + 1))
			done
			speed_test_curl
			kill -9 `ps|grep xray|grep 'tmp_v2ray'|awk '{print $1}'` >/dev/null 2>&1
			rm -f /tmp/tmp_v2ray.json /tmp/v2ray_webtest_log.log

		elif [ "$array12" == "4" -a "$array14" == "Hysteria2" ];then   #Hysteria2
			create_hy2_json 
			export QUIC_GO_DISABLE_ECN=true
			hysteria -c /tmp/tmp_hysteria.json -l error --disable-update-check  >/dev/null 2>&1 &
			speed_test_curl
			kill -9 `ps|grep hysteria|grep 'tmp_hysteria'|awk '{print $1}'` >/dev/null 2>&1	
			rm -f /tmp/tmp_hysteria.json

		elif [ "$array12" == "4" -a "$array14" == "AnyTLS" ];then   #AnyTLS
			if [ -n "$(eval echo \$ssconf_basic_trojan_sni_$nu)" ]; then
				anytls -socks 127.0.0.1:23458 -nat 0.0.0.0:3334 -s "${array1}:${array2}" -p "$array3" -sni "$(eval echo \$ssconf_basic_trojan_sni_$nu)" >/dev/null 2>&1 &
			else
				anytls -socks 127.0.0.1:23458 -nat 0.0.0.0:3334 -s "${array1}:${array2}" -p "$array3" >/dev/null 2>&1 &
			fi
			local i=0
			while [ "$i" -lt 10 ]
			do
				netstat -nl 2>/dev/null | grep -q '[:.]23458[[:space:]]' && break
				sleep 1
				i=$((i + 1))
			done
			speed_test_curl
			kill -9 `ps|grep -w anytls|grep -w '23458'|awk '{print $1}'` >/dev/null 2>&1
			
		elif [ "$array12" == "5" ];then   #naive
			create_naive_json 
			naive /tmp/tmp2_naive.json >/dev/null 2>&1 &
			speed_test_curl
			kill -9 `ps|grep 'naive' | grep 'tmp2_naive'|awk '{print $1}'` >/dev/null 2>&1
			rm -f  /tmp/tmp2_naive.json

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
	server_nu=`dbus list ssconf_basic_name_ | sort -n -t "_" -k 4 | cut -d "=" -f 1 | cut -d "_" -f 4`
	for nu in $server_nu
	do
		start_webtest
	done
fi
