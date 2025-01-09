deploy_docker_swarm_and_portworx_menu() {
    while true; do
        clear
        echo "==============================="
        echo "请选择要执行的操作："
        echo "1. 部署 Docker Swarm 集群"
        echo "2. 部署 Nfs 持久化存储"
        echo "0. 退出"
        echo "==============================="
        read -p "请输入操作的序号 (1/2/0): " choice

        case "$choice" in
            1)
                deploy_docker_swarm
                ;;
            2)
                deploy_portworx_with_persistence
                ;;
            0)
                echo "退出菜单"
                break
                ;;
            *)
                echo "无效选择，请重新输入"
                ;;
        esac
        sleep 2
    done
}

# 部署 Docker Swarm 集群
deploy_docker_swarm() {
    echo "正在部署 Docker Swarm 集群..."

    # 检查是否已经是 Docker Swarm 集群
    if docker info | grep -q "Swarm: active"; then
        echo "Docker Swarm 已经处于活动状态。"
        return
    fi

    # 初始化 Docker Swarm 集群
    docker swarm init --advertise-addr "$(get_public_ip)"
    if [ $? -eq 0 ]; then
        echo "Docker Swarm 集群已成功初始化。"
    else
        echo "Docker Swarm 初始化失败！" >&2
    fi
    pause
}

#!/bin/bash

# 设置 NFS 服务器的共享目录和配置文件
SHARE_DIR="/mnt/nfs_share"
NFS_CONFIG_FILE="/etc/exports"

# 安装 NFS 服务器（根据操作系统选择）
install_nfs_server() {
    if [ -f /etc/debian_version ]; then
        echo "Debian/Ubuntu 系统，安装 NFS 服务器"
        apt-get update
        apt-get install -y nfs-kernel-server
    elif [ -f /etc/redhat-release ]; then
        echo "CentOS/RHEL 系统，安装 NFS 服务器"
        yum install -y nfs-utils
    else
        echo "未知系统，无法自动安装 NFS 服务器"
        exit 1
    fi
}

# 创建共享目录（如果目录不存在）
create_shared_directory() {
    if [ ! -d "$SHARE_DIR" ]; then
        mkdir -p "$SHARE_DIR"
        echo "创建 NFS 共享目录: $SHARE_DIR"
    fi
}

# 配置共享目录并重启 NFS 服务
configure_nfs() {
    echo "配置 NFS 共享目录：$SHARE_DIR"
    echo "$SHARE_DIR *(rw,sync,no_root_squash,no_subtree_check)" > "$NFS_CONFIG_FILE"
    exportfs -ra
    systemctl restart nfs-kernel-server
}

# 配置防火墙规则
configure_firewall() {
    # 获取 NFS 服务端口
    NFS_PORT="2049"

    if [ -f /etc/debian_version ]; then
        ufw allow from $1 to any port $NFS_PORT
    elif [ -f /etc/redhat-release ]; then
        firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=$1 accept"
        firewall-cmd --reload
    fi
}

# 添加 IP 地址到白名单
add_ip_to_whitelist() {
    echo "请输入要添加到白名单的 IP 地址或 IP 范围（例如：192.168.1.0/24 或单一 IP：192.168.1.100）："
    read -p "请输入 IP 地址或范围: " ALLOWED_IP
    if [ -z "$ALLOWED_IP" ]; then
        echo "错误：没有提供 IP 地址或范围，操作取消。"
        return
    fi
    echo "添加 $ALLOWED_IP 到 NFS 白名单"
    echo "$SHARE_DIR $ALLOWED_IP(rw,sync,no_root_squash,no_subtree_check)" >> "$NFS_CONFIG_FILE"
    exportfs -ra
    configure_firewall "$ALLOWED_IP"
    echo "$ALLOWED_IP 已成功添加到白名单。"
}

# 删除 IP 地址从白名单
remove_ip_from_whitelist() {
    echo "请输入要删除的 IP 地址或 IP 范围（例如：192.168.1.100 或 192.168.1.0/24）："
    read -p "请输入要删除的 IP 地址或范围: " REMOVE_IP
    if [ -z "$REMOVE_IP" ]; then
        echo "错误：没有提供 IP 地址或范围，操作取消。"
        return
    fi
    echo "删除 $REMOVE_IP 从 NFS 白名单"
    sed -i "/$REMOVE_IP/d" "$NFS_CONFIG_FILE"
    exportfs -ra
    echo "$REMOVE_IP 已成功从白名单中删除。"
}

# 查看当前的 NFS 白名单
view_current_whitelist() {
    echo "当前的 NFS 白名单："
    grep "$SHARE_DIR" "$NFS_CONFIG_FILE"
}

# 主菜单函数
nfs_server_management_menu() {
    echo "欢迎使用 NFS 服务器管理脚本"
    PS3="请选择一个操作: "
    select opt in "部署 NFS 服务器" "添加 IP 白名单" "删除 IP 白名单" "查看当前白名单" "退出"; do
        case $opt in
            "部署 NFS 服务器")
                install_nfs_server
                create_shared_directory
                configure_nfs
                echo "NFS 服务器部署完成!"
                ;;
            "添加 IP 白名单")
                add_ip_to_whitelist
                ;;
            "删除 IP 白名单")
                remove_ip_from_whitelist
                ;;
            "查看当前白名单")
                view_current_whitelist
                ;;
            "退出")
                echo "退出脚本。"
                break
                ;;
            *)
                echo "无效的选项，请重新选择。"
                ;;
        esac
    done
}




# 暂停功能
pause() {
    read -p "按 Enter 键继续..."
}
