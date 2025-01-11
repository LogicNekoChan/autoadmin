deploy_docker_swarm_and_nfs_menu() {
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
                deploy_nfs_with_persistence
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
MOUNT_DIR="/mnt/nfs_mount"
SERVER_IP_FILE="/etc/nfs_server_ip.txt"

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
    NFS_PORT="2049"
    if [ -f /etc/debian_version ]; then
        ufw allow from $1 to any port $NFS_PORT
    elif [ -f /etc/redhat-release ]; then
        firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=$1 accept"
        firewall-cmd --reload
    fi
}

# 部署 NFS 服务端
deploy_nfs_server() {
    install_nfs_server
    create_shared_directory
    configure_nfs
    echo "NFS 服务端已部署成功！"

    # 获取服务端的 IP 地址并记录
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo "NFS 服务器的 IP 地址是：$SERVER_IP"
    
    # 保存服务器 IP 地址到文件
    echo "$SERVER_IP" > "$SERVER_IP_FILE"
    echo "已记录 NFS 服务器的 IP 地址：$SERVER_IP"
}

# 获取 NFS 服务器 IP 地址
get_nfs_server_ip() {
    if [ -f "$SERVER_IP_FILE" ]; then
        cat "$SERVER_IP_FILE"
    else
        echo "NFS 服务器 IP 地址未记录！"
        return 1
    fi
}

# 更换 NFS 服务器 IP 地址
change_nfs_server_ip() {
    echo "请输入新的 NFS 服务器 IP 地址："
    read -p "新的 NFS 服务器 IP: " NEW_SERVER_IP

    if [ -z "$NEW_SERVER_IP" ]; then
        echo "错误：没有提供新的 IP 地址，操作取消。"
        return
    fi

    # 更新 IP 地址文件
    echo "$NEW_SERVER_IP" > "$SERVER_IP_FILE"
    echo "NFS 服务器的 IP 地址已更改为：$NEW_SERVER_IP"
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
    echo "当前的 NFS 白名单："
    grep "$SHARE_DIR" "$NFS_CONFIG_FILE" | nl -s". "   # 按序号列出白名单

    # 提示用户选择删除的 IP
    echo "请输入要删除的白名单序号："
    read -p "选择序号: " REMOVE_INDEX

    # 获取对应序号的 IP 地址行
    REMOVE_IP=$(grep "$SHARE_DIR" "$NFS_CONFIG_FILE" | sed -n "${REMOVE_INDEX}p" | awk '{print $1}')
    
    if [ -z "$REMOVE_IP" ]; then
        echo "错误：没有找到对应的 IP 地址，操作取消。"
        return
    fi

    # 删除对应的 IP 地址
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

# NFS 客户端挂载
nfs_client_mount() {
    # 提示用户输入 NFS 服务器的 IP 地址
    echo "请输入 NFS 服务器的 IP 地址："
    read -p "NFS 服务器 IP: " NEW_SERVER_IP

    if [ -z "$NEW_SERVER_IP" ]; then
        echo "错误：没有提供 NFS 服务器 IP，操作取消。"
        return
    fi

    # 检查 NFS 服务器是否可达
    echo "正在检查 NFS 服务器的可达性..."
    ping -c 4 "$NEW_SERVER_IP" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "错误：无法访问 NFS 服务器 $NEW_SERVER_IP，操作取消。"
        return
    fi

    # 设置挂载路径
    LOCAL_MOUNT_DIR="/mnt/nfs_mount"
    if [ ! -d "$LOCAL_MOUNT_DIR" ]; then
        mkdir -p "$LOCAL_MOUNT_DIR"
        echo "创建挂载目录: $LOCAL_MOUNT_DIR"
    fi

    # 检查 NFS 服务器的共享目录是否存在
    echo "正在检查共享目录 $SHARE_DIR 是否存在..."
    SHOW_SHARE=$(showmount -e "$NEW_SERVER_IP" 2>/dev/null | grep "$SHARE_DIR")
    if [ -z "$SHOW_SHARE" ]; then
        echo "错误：NFS 服务器上没有找到共享目录 $SHARE_DIR，操作取消。"
        return
    fi

    # 挂载 NFS
    echo "挂载 NFS 文件系统 $NEW_SERVER_IP:$SHARE_DIR 到 $LOCAL_MOUNT_DIR..."
    mount -t nfs -o nfsvers=4,rw,sync "$NEW_SERVER_IP:$SHARE_DIR" "$LOCAL_MOUNT_DIR"

    if [ $? -eq 0 ]; then
        echo "NFS 挂载成功！"
    else
        echo "NFS 挂载失败！" >&2
        echo "请检查 NFS 服务器和挂载选项。"
        dmesg | tail -n 20   # 查看最近的内核日志
    fi
}

# 主菜单
deploy_nfs_with_persistence() {
    while true; do
        clear
        echo "==============================="
        echo "请选择要执行的操作："
        echo "1. 部署 NFS 服务端"
        echo "2. 更换 NFS 服务器 IP 地址"
        echo "3. 添加 IP 白名单"
        echo "4. 删除 IP 白名单"
        echo "5. 查看当前 NFS 白名单"
        echo "6. 部署 NFS 客户端"
        echo "0. 退出"
        echo "==============================="
        read -p "请输入操作的序号 (1/2/3/4/5/6/0): " choice

        case "$choice" in
            1)
                deploy_nfs_server
                ;;
            2)
                change_nfs_server_ip
                ;;
            3)
                add_ip_to_whitelist
                ;;
            4)
                remove_ip_from_whitelist
                ;;
            5)
                view_current_whitelist
                ;;
            6)
                nfs_client_mount
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

# 暂停功能
pause() {
    read -p "按 Enter 键继续..."
}
