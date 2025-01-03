#!/bin/bash

re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
reading() { read -p "$(red "$1")" "$2"; }
export LC_ALL=C
USERNAME=$(whoami)
HOSTNAME=$(hostname)
export UUID=${UUID:-'bc97f674-c578-4940-9234-0a1da46041b0'}
export BESZEL_KEY=${BESZEL_KEY:-''} 
export ARGO_DOMAIN=${ARGO_DOMAIN:-''}   
export ARGO_AUTH=${ARGO_AUTH:-''}
export TCP_PORT=${TCP_PORT:-'11226'}
export SOCKSU=${SOCKSU:-'oneforall'}
export SOCKSP=${SOCKSP:-'allforone'}
export UDP_PORT=${UDP_PORT:-'11227'}
export CFIP=${CFIP:-'www.visa.com.tw'} 
export CFPORT=${CFPORT:-'443'} 

[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="domains/${USERNAME}.ct8.pl/logs" || WORKDIR="domains/${USERNAME}.serv00.net/logs"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")
bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1
# devil binexec on > /dev/null 2>&1

argo_configure() {
clear
purple "正在安装中,请稍等..."
  if [[ -z $ARGO_AUTH || -z $ARGO_DOMAIN ]]; then
    green "ARGO_DOMAIN or ARGO_AUTH is empty,use quick tunnel"
    return
  fi

  if [[ $ARGO_AUTH =~ TunnelSecret ]]; then
    echo $ARGO_AUTH > tunnel.json
    cat > tunnel.yml << EOF
tunnel: $(cut -d\" -f12 <<< "$ARGO_AUTH")
credentials-file: tunnel.json
protocol: http2

ingress:
  - hostname: $ARGO_DOMAIN
    service: http://localhost:$TCP_PORT
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
  else
    green "ARGO_AUTH mismatch TunnelSecret,use token connect to tunnel"
  fi
}

generate_config() {

    openssl ecparam -genkey -name prime256v1 -out "private.key"
    openssl req -new -x509 -days 3650 -key "private.key" -out "cert.pem" -subj "/CN=$USERNAME.serv00.net"

    yellow "正在进行连通性测试，请稍等..."
    available_ips=$(get_ip)
    purple "$available_ips"
  
  cat > config.json << EOF
{
  "log": {
    "disabled": true,
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "address": "8.8.8.8",
        "address_resolver": "local"
      },
      {
        "tag": "local",
        "address": "local"
      }
    ]
  },
  "inbounds": [
    {
       "tag": "hysteria-in",
       "type": "hysteria2",
       "listen": "$IP3",
       "listen_port": $UDP_PORT,
       "users": [
         {
             "password": "$UUID"
         }
     ],
     "masquerade": "https://bing.com",
     "tls": {
         "enabled": true,
         "alpn": [
             "h3"
         ],
         "certificate_path": "cert.pem",
         "key_path": "private.key"
        }
    },
    {
      "tag": "vless-ws-in",
      "type": "vless",
      "listen": "127.0.0.1",
      "listen_port": $TCP_PORT,
      "users": [
      {
        "uuid": "$UUID"
      }
    ],
    "transport": {
      "type": "ws",
      "path": "/vless-argo",
      "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    },
    {
      "tag": "socks-in",
      "type": "socks",
      "listen": "$IP2",
      "listen_port": $TCP_PORT,
      "users": [
        {
          "username": "$SOCKSU",
          "password": "$SOCKSP"
        }
      ]
    },
    {
      "tag": "tuic-in",
      "type": "tuic",
      "listen": "$IP4",
      "listen_port": $UDP_PORT,
      "users": [
        {
          "uuid": "$UUID",
          "password": "admin123"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "cert.pem",
        "key_path": "private.key"
      }
    }
 ],
  "outbounds": [
    {
      "type": "socks",
      "tag": "socks5_outbound",
      "server": "s9.serv00.com",
      "server_port": 1766,
      "version": "5",
      "username": "oneforall",
      "password": "allforone"
    },
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "block",
      "type": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "domain": [
          "usher.ttvnw.net",
          "jnn-pa.googleapis.com"
        ],
        "outbound": "socks5_outbound"
      }
    ],
  "final": "direct"
  }
}
EOF
}

download_singbox() {
  DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
  FILE_INFO=("https://github.com/eooce/test/releases/download/freebsd/sb web" \
             "https://github.com/eooce/test/releases/download/freebsd/server bot" \
             "https://github.com/henrygd/beszel/releases/latest/download/beszel-agent_freebsd_amd64.tar.gz npm")

declare -A FILE_MAP

generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
    local name=""
    for i in {1..6}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}

download_with_fallback() {
    local URL=$1
    local NEW_FILENAME=$2

    curl -L -sS --max-time 3 -o "$NEW_FILENAME" "$URL" &
    CURL_PID=$!
    CURL_START_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
      
    sleep 1

    CURL_CURRENT_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
      
    if [ "$CURL_CURRENT_SIZE" -le "$CURL_START_SIZE" ]; then
        kill $CURL_PID 2>/dev/null
        wait $CURL_PID 2>/dev/null
        wget -q -O "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloading $NEW_FILENAME by wget\e[0m"
    else
        wait $CURL_PID
        echo -e "\e[1;32mDownloading $NEW_FILENAME by curl\e[0m"
    fi
}

for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    LOGIC_NAME=$(echo "$entry" | cut -d ' ' -f 2)
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
      
    if [ -e "$NEW_FILENAME" ]; then
        echo -e "\e[1;32m$NEW_FILENAME already exists, Skipping download\e[0m"
    else
        download_with_fallback "$URL" "$NEW_FILENAME"
    fi
      
    if [[ "$URL" == *.tar.gz ]]; then
        tar -xzf "$NEW_FILENAME" -C "$DOWNLOAD_DIR"
        rm -f "$NEW_FILENAME"
    
        EXTRACTED_FILE="$DOWNLOAD_DIR/beszel-agent"
        if [ ! -f "$EXTRACTED_FILE" ]; then
            echo -e "\e[1;31mError: Expected file 'beszel-agent' not found in archive\e[0m"
            continue
        fi
    
        mv "$EXTRACTED_FILE" "$NEW_FILENAME"
    fi

    chmod +x "$NEW_FILENAME"
    FILE_MAP[$LOGIC_NAME]="$NEW_FILENAME"
done
wait

if [ -e "$(basename ${FILE_MAP[npm]})" ]; then
    if [ -n "$TCP_PORT" ] && [ -n "$BESZEL_KEY" ]; then
        nohup env PORT=$IP1:$TCP_PORT KEY="ssh-ed25519 $BESZEL_KEY" ./"$(basename ${FILE_MAP[npm]})" > /dev/null 2>&1 &
        sleep 2
        pgrep -x "$(basename ${FILE_MAP[npm]})" > /dev/null && green "$(basename ${FILE_MAP[npm]}) is running" || { red "$(basename ${FILE_MAP[npm]}) is not running, restarting..."; pkill -x "$(basename ${FILE_MAP[npm]})" && nohup env PORT=$IP1:$TCP_PORT KEY="ssh-ed25519 $BESZEL_KEY" ./"$(basename ${FILE_MAP[npm]})" > /dev/null 2>&1 & sleep 2; purple "$(basename ${FILE_MAP[npm]}) restarted"; }
    else
        purple "BESZEL variable is empty, skipping running"
    fi
fi

if [ -e "$(basename ${FILE_MAP[web]})" ]; then
    nohup ./"$(basename ${FILE_MAP[web]})" run -c config.json >/dev/null 2>&1 &
    sleep 2
    pgrep -x "$(basename ${FILE_MAP[web]})" > /dev/null && green "$(basename ${FILE_MAP[web]}) is running" || { red "$(basename ${FILE_MAP[web]}) is not running, restarting..."; pkill -x "$(basename ${FILE_MAP[web]})" && nohup ./"$(basename ${FILE_MAP[web]})" run -c config.json >/dev/null 2>&1 & sleep 2; purple "$(basename ${FILE_MAP[web]}) restarted"; }
fi

if [ -e "$(basename ${FILE_MAP[bot]})" ]; then
    if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
      args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
    elif [[ $ARGO_AUTH =~ TunnelSecret ]]; then
      args="tunnel --edge-ip-version auto --config tunnel.yml run"
    else
      args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile boot.log --loglevel info --url http://localhost:$TCP_PORT"
    fi
    nohup ./"$(basename ${FILE_MAP[bot]})" $args >/dev/null 2>&1 &
    sleep 2
    pgrep -x "$(basename ${FILE_MAP[bot]})" > /dev/null && green "$(basename ${FILE_MAP[bot]}) is running" || { red "$(basename ${FILE_MAP[bot]}) is not running, restarting..."; pkill -x "$(basename ${FILE_MAP[bot]})" && nohup ./"$(basename ${FILE_MAP[bot]})" "${args}" >/dev/null 2>&1 & sleep 2; purple "$(basename ${FILE_MAP[bot]}) restarted"; }
fi
sleep 2
rm -f "$(basename ${FILE_MAP[npm]})" "$(basename ${FILE_MAP[web]})" "$(basename ${FILE_MAP[bot]})"
}
 
get_argodomain() {
  if [[ -n $ARGO_AUTH ]]; then
    echo "$ARGO_DOMAIN"
  else
    local retry=0
    local max_retries=6
    local argodomain=""
    while [[ $retry -lt $max_retries ]]; do
      ((retry++))
      argodomain=$(grep -oE 'https://[[:alnum:]+\.-]+\.trycloudflare\.com' boot.log | sed 's@https://@@') 
      if [[ -n $argodomain ]]; then
        break
      fi
      sleep 1
    done
    echo "$argodomain"
  fi
}

get_ip() {
    IP_LIST=($(devil vhost list | awk '/^[0-9]+/ {print $1}'))

    AVAILABLE_IPS=""
    for IP in "${IP_LIST[@]}"; do
        RESPONSE=$(curl -s 'https://api.ycwxgzs.com/ipcheck/index.php' --data "ip=$IP&port=22" | jq -r '.tcp, .icmp' | sed 's/<[^>]*>//g')
        if [[ $RESPONSE =~ "端口可用" && $RESPONSE =~ "IP可用" ]]; then
            AVAILABLE_IPS+=" $IP(通)"
        else
            AVAILABLE_IPS+=" $IP(不通)"
        fi
    done

    IP1=""
    IP2=""
    IP3=""
    IP4=""

    RESPONSIVE_IPS=()
    for IP in "${IP_LIST[@]}"; do
        RESPONSE=$(curl -s 'https://api.ycwxgzs.com/ipcheck/index.php' --data "ip=$IP&port=22" | jq -r '.tcp, .icmp' | sed 's/<[^>]*>//g')
        if [[ $RESPONSE =~ "端口可用" && $RESPONSE =~ "IP可用" ]]; then
            RESPONSIVE_IPS+=($IP)
        fi
    done

    if [ ${#IP_LIST[@]} -gt 0 ]; then
        IP1=${IP_LIST[0]}
    fi
    if [ ${#IP_LIST[@]} -gt 1 ]; then
        IP2=${IP_LIST[1]}
    fi

    if [ ${#RESPONSIVE_IPS[@]} -gt 0 ]; then
        IP3=${RESPONSIVE_IPS[0]}
    fi
    if [ ${#RESPONSIVE_IPS[@]} -gt 1 ]; then
        IP4=${RESPONSIVE_IPS[1]}
    fi

    echo "$AVAILABLE_IPS"
    IP1=$IP1
    IP2=$IP2
    IP3=$IP3
    IP4=$IP4
    AVAILABLE_IPS=$AVAILABLE_IPS
}

get_ip

get_links(){
argodomain=$(get_argodomain)
echo -e "\e[1;32mArgoDomain:\e[1;35m${argodomain}\e[0m\n"
ISP=$(curl -s --max-time 1.5 https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g' || echo "0")
get_name() { if [ "$HOSTNAME" = "s1.ct8.pl" ]; then SERVER="CT8"; else SERVER=$(echo "$HOSTNAME" | cut -d '.' -f 1); fi; echo "$SERVER"; }
NAME="$ISP-$(get_name)"

yellow "注意：v2ray或其他软件的跳过证书验证需设置为true,否则hy2或tuic节点可能不通\n"
purple "Beszel探针的IP是$IP1端口是$TCP_PORT\n"
cat > list.txt <<EOF
socks5://$SOCKSU:$SOCKSP@$IP2:$TCP_PORT#$NAME-socks5

vless://${UUID}@${CFIP}:${CFPORT}?encryption=none&security=tls&sni=${argodomain}&type=ws&host=${argodomain}&path=%2Fvless-argo%3Fed%3D2048#${NAME}-vless-argo

hysteria2://$UUID@$IP3:$UDP_PORT/?sni=www.bing.com&alpn=h3&insecure=1#$NAME-hy2

tuic://$UUID:admin123@$IP4:$UDP_PORT?sni=www.bing.com&congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#$NAME-tuic
EOF
cat list.txt
purple "\n$WORKDIR/list.txt saved successfully"
purple "Running done!"
yellow "这是Serv00 S14 S15专用的魔改老王四合一脚本(socks5|vless-ws-tls(argo)|hysteria2|tuic)\n"
echo -e "${green}解决的问题：${re}${yellow}S14不能正常播放YouTube，S15不能正常播放Twitch的问题${re}\n"
echo -e "${green}反馈：${re}${yellow}不要去找老王就行，魔改没有售后${re}\n"
echo -e "${green}TG反馈：${re}${yellow}你可以在https://t.me/CMLiussss里找到我 @RealNeoMan${re}\n"
purple "转载请著名出处，请勿滥用\n"
sleep 3 
rm -rf boot.log config.json sb.log core tunnel.yml tunnel.json fake_useragent_0.2.0.json

}

install_singbox() {
    clear
    cd $WORKDIR
    argo_configure
    generate_config
    download_singbox
    get_links
}
install_singbox
