#!/bin/bash

# 获取本机公网 IP，优先使用 IPv4
get_public_ip() {
    # 尝试获取 IPv4 地址
    public_ip=$(curl -s4 http://whatismyip.akamai.com || curl -s4 https://api.ipify.org)
    
    # 如果没有 IPv4 地址，则尝试获取 IPv6 地址
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s6 http://whatismyip.akamai.com || curl -s6 https://api.ipify.org)
    fi

    # 返回公网 IP 地址
    echo "$public_ip"
}

# NPS 安装和配置
install_nps() {
    echo "开始安装 NPS..."

    # 设置 NPS 项目路径
    NPS_DIR="/root/nps"

    # 检查 Docker 是否已安装
    command -v docker >/dev/null 2>&1 || { echo "请先安装 Docker"; exit 1; }

    # 克隆 NPS 项目
    mkdir -p "$NPS_DIR"
    cd "$NPS_DIR"
    if [ ! -d ".git" ]; then
        git clone https://github.com/ehang-io/nps.git . || { echo "克隆 NPS 代码失败"; exit 1; }
    fi

    # 检查并创建配置文件
    if [ ! -f "conf/nps.conf" ]; then
        echo "未找到 conf/nps.conf，正在创建默认配置..."
        cp conf/nps.conf.example conf/nps.conf || { echo "配置文件创建失败！"; exit 1; }
    fi

    # 获取本机公网 IP
    local public_ip=$(get_public_ip)

    # 交互式获取配置参数
    echo "检测到公网 IP: $public_ip"
    read -p "请确认或修改 http_proxy_port 的值 (默认 8080): " http_proxy_port
    read -p "请确认或修改 https_proxy_port 的值 (默认 443): " https_proxy_port
    read -p "请输入 web_username 的值: " web_username
    read -p "请输入 web_password 的值: " web_password
    read -p "请输入 auth_crypt_key 的值: " auth_crypt_key

    # 设置默认值
    http_proxy_port=${http_proxy_port:-8080}
    https_proxy_port=${https_proxy_port:-443}
    web_ip=$public_ip

    # 修改配置文件
    sed -i "s/^http_proxy_port=.*$/http_proxy_port=${http_proxy_port}/" conf/nps.conf
    sed -i "s/^https_proxy_port=.*$/https_proxy_port=${https_proxy_port}/" conf/nps.conf
    sed -i "s/^web_username=.*$/web_username=${web_username}/" conf/nps.conf
    sed -i "s/^web_password=.*$/web_password=${web_password}/" conf/nps.conf
    sed -i "s/^web_ip=.*$/web_ip=${web_ip}/" conf/nps.conf
    sed -i "s/^auth_crypt_key=.*$/auth_crypt_key=${auth_crypt_key}/" conf/nps.conf

    # 运行 Docker 容器
    docker run -d --name nps --net=host -v "$NPS_DIR/conf":/conf --restart=always yisier1/nps || { echo "启动 NPS 容器失败"; exit 1; }

    # 显示访问地址并提示用户按 Enter 键退出
    echo "NPS 容器已启动，请访问 http://${web_ip}:${http_proxy_port} 进行管理"
    pause
}

# WireGuard-Easy 安装和配置
install_wireguard_easy() {
    echo "开始安装 WireGuard-Easy..."

    # 检查 Docker 是否已安装
    command -v docker >/dev/null 2>&1 || { echo "请先安装 Docker"; exit 1; }

    # 获取本机公网 IP
    local public_ip=$(get_public_ip)

    # 交互式获取配置参数
    echo "检测到公网 IP: $public_ip"
    read -p "请输入 WireGuard 管理账户密码: " WG_PASSWORD

    # 默认 WireGuard 服务端口
    WG_PORT=51820

    # 创建 WireGuard-Easy 配置目录
    mkdir -p /root/wireguard

    # 创建 Docker Compose 配置文件
    cat > /root/wireguard/docker-compose.yml <<EOF
version: '3.3'
services:
  wg-easy:
    image: weejewel/wg-easy
    container_name: wg-easy
    environment:
      - WG_HOST=${public_ip}
      - PASSWORD=${WG_PASSWORD}
      - WG_PORT=${WG_PORT}
    volumes:
      - /root/wireguard:/etc/wireguard
    ports:
      - 51822:51820/udp
      - 51821:51821/tcp
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
EOF

    # 运行 WireGuard-Easy Docker 容器
    cd /root/wireguard
    docker compose up -d || { echo "启动 WireGuard-Easy 容器失败"; exit 1; }

    # 显示访问地址并提示用户按 Enter 键退出
    echo "WireGuard-Easy 安装完成！请使用以下信息进行管理："
    echo "  - 公网 IP: ${public_ip}"
    echo "  - 管理密码: ${WG_PASSWORD}"
    echo "  - 服务端口: ${WG_PORT}"
    echo "请访问 http://${public_ip}:51821 管理 WireGuard"
    pause
}

# 内网端口转发管理菜单
port_forwarding_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      内网端口转发功能菜单     "
        echo "==============================="
        echo "1. 安装 NPS"
        echo "2. 安装 WireGuard-Easy"
        echo "3. 返回主菜单"
        echo "==============================="
        read -p "请选择一个选项 (1-3): " choice

        case $choice in
            1) install_nps ;;              # 安装 NPS
            2) install_wireguard_easy ;;   # 安装 WireGuard-Easy
            3) return ;;                   # 返回主菜单
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
    done
}

# 暂停等待用户按键
pause() {
    read -p "按 Enter 键继续..."
}
