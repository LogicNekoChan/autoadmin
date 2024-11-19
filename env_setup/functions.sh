#!/bin/bash

# 快速部署菜单
system_maintenance_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      快速部署菜单       "
        echo "==============================="
        echo "1. 自动化系统初始化"
        echo "2. 返回主菜单"
        echo "==============================="
        read -p "请选择一个选项 (1-2): " deploy_choice

        case $deploy_choice in
            1)
                system_auto_setup
                pause
                ;;
            2)
                return
                ;;
            *)
                echo "无效选项，请重试"
                sleep 2
                ;;
        esac
    done
}

# 自动化系统初始化
system_auto_setup() {
    echo "正在检测系统信息..."
    local os_type=""
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_type=$ID
    else
        echo "无法检测系统信息，脚本支持 Ubuntu 和 Debian 系统。"
        return
    fi

    echo "当前系统: $NAME $VERSION"
    echo "开始执行系统初始化..."

    echo "1. 更新系统并安装基本依赖..."
    case $os_type in
        ubuntu | debian)
            sudo apt update -y && sudo apt upgrade -y
            sudo apt install -y sudo neofetch vim jq curl yq
            ;;
        *)
            echo "当前系统不支持，请手动安装依赖。"
            return
            ;;
    esac
    echo "系统更新和依赖安装完成。"

    echo "2. 设置系统时间为上海时间..."
    sudo timedatectl set-timezone Asia/Shanghai
    echo "当前系统时间: $(date)"

    echo "3. 启用 BBR 模式..."
    enable_bbr

    echo "4. 设置 Swap 空间..."
    setup_swap

    echo "5. 设置密钥登录并禁用密码登录..."
    setup_ssh_key_auth

    echo "6. 安装 Docker 和 Docker Compose..."
    install_docker

    echo "系统初始化已完成。"
}

# 启用 BBR 模式
enable_bbr() {
    sudo modprobe tcp_bbr
    echo "tcp_bbr" | sudo tee -a /etc/modules-load.d/bbr.conf >/dev/null
    echo "net.core.default_qdisc = fq" | sudo tee -a /etc/sysctl.conf >/dev/null
    echo "net.ipv4.tcp_congestion_control = bbr" | sudo tee -a /etc/sysctl.conf >/dev/null
    sudo sysctl -p >/dev/null

    if lsmod | grep -q bbr; then
        echo "BBR 模式已成功启用。"
    else
        echo "BBR 模式启用失败，请手动检查配置。"
    fi
}

# 设置 Swap 空间
setup_swap() {
    local total_disk_size=$(df --output=size / | tail -1)
    local swap_size=2048

    # 如果硬盘小于 10GB，设置较小的 Swap 空间
    if [ "$total_disk_size" -lt 10240 ]; then
        swap_size=500
    fi

    echo "检测到系统硬盘大小: $((total_disk_size / 1024)) MB，设置 Swap 为 ${swap_size}MB..."
    sudo swapoff -a
    sudo dd if=/dev/zero of=/swapfile bs=1M count=$swap_size
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab >/dev/null

    echo "Swap 设置完成，当前 Swap 空间: $(free -m | awk '/Swap/ {print $2}') MB"
}

# 设置 SSH 密钥登录并禁用密码登录
setup_ssh_key_auth() {
    local ssh_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCzx8GlO5jVkNiwBG57J2zVwllC1WHQbRaFVI8H5u+fZnt3YuuIsCJBCRfM7/7Ups6wdEVwhgk+PEq8nE3WgZ8SBgNoAO+CgZprdDi+nx7zBRqrHw9oJcHQysiAw+arRW29g2TZgVhszjVq5G6MoVYGjnnPzLEcZS37by0l9eZD9u1hAB4FtIdw+VfrfJG177HLfiLkSm6PkO3QMWTYGmGjE3zpMxWeascWCn6UTDpjt6UiSMgcmAlx4FP8mkRRMc5TvxqnUKbgdjYBU2V+dZQx1keovrd0Yh8KitPEGd6euok3e7WmtLQlXH8WOiPlCr2YJfW3vQjlDVg5UU83GSGr root@mintcat"

    echo "清除现有的授权密钥..."
    sudo rm -rf ~/.ssh
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    echo "添加新的公钥到 authorized_keys..."
    echo "$ssh_key" > ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys

    echo "修改 SSH 配置以禁用密码登录..."
    sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

    echo "重启 SSH 服务以应用更改..."
    sudo systemctl restart sshd

    echo "SSH 密钥登录已配置，密码登录已禁用。"
}

# 安装 Docker 和 Docker Compose
install_docker() {
    echo "正在安装 Docker 和 Docker Compose..."
    
    # 安装 Docker
    curl -fsSL https://get.docker.com | bash -s docker
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "Docker 安装完成。"

    # 安装 Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose 安装完成。"
}

# 暂停等待用户按键
pause() {
    read -p "按 Enter 键继续..."
}