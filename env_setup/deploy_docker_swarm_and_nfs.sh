#!/bin/bash

# 设置共享目录和相关配置
SHARE_DIR="/mnt/nfs_share"
NFS_CONFIG_FILE="/etc/exports"
MOUNT_DIR="/mnt/nfs_mount"
SERVER_IP_FILE="/etc/nfs_server_ip.txt"

# 暂停功能
pause() {
        read -p "按 Enter 键继续..."
}

# 安装 NFS 服务端
install_nfs_server() {
        if [ -f /etc/debian_version ]; then
                echo "Debian/Ubuntu 系统，安装 NFS 服务端..."
                apt-get update
                apt-get install -y nfs-kernel-server
        elif [ -f /etc/redhat-release ]; then
                echo "CentOS/RHEL 系统，安装 NFS 服务端..."
                yum install -y nfs-utils
        else
                echo "未知系统，无法自动安装 NFS 服务端。"
                exit 1
        fi
}

# 创建共享目录
create_shared_directory() {
        if [ ! -d "$SHARE_DIR" ]; then
                mkdir -p "$SHARE_DIR"
                chmod 777 "$SHARE_DIR"
                echo "创建共享目录: $SHARE_DIR"
        else
                echo "共享目录已存在: $SHARE_DIR"
        fi
}

# 配置 NFS 服务
configure_nfs() {
        echo "$SHARE_DIR *(rw,sync,no_root_squash,no_subtree_check)" > "$NFS_CONFIG_FILE"
        exportfs -ra
        systemctl restart nfs-kernel-server
        echo "NFS 配置已完成，服务已重启。"
}

# 配置防火墙
configure_firewall() {
        local ALLOWED_IP="$1"
        if [ -f /etc/debian_version ]; then
                ufw allow from "$ALLOWED_IP" to any port 2049
                echo "已为 $ALLOWED_IP 开放 NFS 访问权限。"
        elif [ -f /etc/redhat-release ]; then
                firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=$ALLOWED_IP accept"
                firewall-cmd --reload
                echo "已为 $ALLOWED_IP 配置防火墙规则。"
        else
                echo "未知系统，无法配置防火墙规则。"
        fi
}

# 删除防火墙规则
remove_firewall_rule() {
        local REMOVED_IP="$1"
        if [ -f /etc/debian_version ]; then
                ufw delete allow from "$REMOVED_IP" to any port 2049
                echo "已删除 $REMOVED_IP 的 NFS 访问权限。"
        elif [ -f /etc/redhat-release ]; then
                firewall-cmd --permanent --remove-rich-rule="rule family=ipv4 source address=$REMOVED_IP accept"
                firewall-cmd --reload
                echo "已删除 $REMOVED_IP 的防火墙规则。"
        else
                echo "未知系统，无法删除防火墙规则。"
        fi
}

# 部署 NFS 服务端
deploy_nfs_server() {
        install_nfs_server
        create_shared_directory
        configure_nfs
        local SERVER_IP=$(hostname -I | awk '{print $1}')
        echo "$SERVER_IP" > "$SERVER_IP_FILE"
        echo "NFS 服务端已成功部署，IP 地址: $SERVER_IP"
}

# NFS 客户端挂载
nfs_client_mount() {
        echo "请输入 NFS 服务器的 IP 地址："
        read -p "NFS 服务器 IP: " SERVER_IP

        if [ -z "$SERVER_IP" ]; then
                echo "错误：未提供 NFS 服务器 IP 地址。"
                return
        fi

        # 检查并安装必要工具
        if ! command -v showmount > /dev/null; then
                echo "正在安装必要工具..."
                if [ -f /etc/debian_version ]; then
                        apt-get update
                        apt-get install -y nfs-common
                elif [ -f /etc/redhat-release ]; then
                        yum install -y nfs-utils
                else
                        echo "未知系统，无法自动安装工具。请手动安装 NFS 客户端工具。"
                        return
                fi
        fi

        # 检查 NFS 服务器是否可达
        ping -c 4 "$SERVER_IP" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
                echo "错误：无法访问 NFS 服务器 $SERVER_IP。"
                return
        fi

        # 输入共享目录
        read -p "请输入 NFS 共享目录路径 (例如：/mnt/nfs_mount): " SHARE_DIR
        if [ -z "$SHARE_DIR" ]; then
                echo "错误：未提供共享目录路径。"
                return
        fi

        # 检查共享目录是否存在
        echo "正在检查共享目录是否存在..."
        if ! showmount -e "$SERVER_IP" | grep -q "$SHARE_DIR"; then
                echo "错误：NFS 服务器上未找到共享目录 $SHARE_DIR。"
                return
        fi

        # 输入本地挂载目录
        read -p "请输入本地挂载目录 (例如：/mnt/nfs_mount_local): " MOUNT_DIR
        if [ -z "$MOUNT_DIR" ]; then
                echo "错误：未提供本地挂载目录。"
                return
        fi

        # 创建挂载目录
        if [ ! -d "$MOUNT_DIR" ]; then
                mkdir -p "$MOUNT_DIR"
                echo "创建挂载目录: $MOUNT_DIR"
        fi

        # 挂载 NFS 共享目录
        echo "挂载 NFS 共享目录..."
        mount -t nfs -o nfsvers=4 "$SERVER_IP:$SHARE_DIR" "$MOUNT_DIR"

        if [ $? -eq 0 ]; then
                echo "NFS 挂载成功: $MOUNT_DIR"
        else
                echo "NFS 挂载失败，请检查日志。"
                dmesg | tail -n 20
                return
        fi

        # 创建 Docker 本地卷，挂载 NFS 共享目录
        echo "创建 Docker 卷..."
        docker volume create --driver local \
          --opt type=nfs \
          --opt o=addr="$SERVER_IP",rw \
          --opt device=":$SHARE_DIR" \
          nfsdata

        if [ $? -eq 0 ]; then
                echo "Docker 卷创建成功：nfsdata"
        else
                echo "Docker 卷创建失败，请检查日志。"
                return
        fi
}

# 主菜单
deploy_docker_swarm_and_nfs_menu() {
        while true; do
                clear
                echo "==============================="
                echo "请选择要执行的操作："
                echo "1. 部署 NFS 服务端"
                echo "2. 添加 IP 白名单"
                echo "3. 删除 IP 白名单"
                echo "4. 挂载 NFS 客户端"
                echo "0. 退出"
                echo "==============================="
                read -p "请输入操作的序号 (1/2/3/4/0): " choice

                case "$choice" in
                        1)
                                deploy_nfs_server
                                ;;
                        2)
                                echo "请输入允许访问的 IP 地址或范围："
                                read -p "IP 地址或范围: " ALLOWED_IP
                                if [ -z "$ALLOWED_IP" ]; then
                                        echo "错误：未提供 IP 地址。"
                                else
                                        configure_firewall "$ALLOWED_IP"
                                fi
                                ;;
                        3)
                                echo "请输入要删除的 IP 地址或范围："
                                read -p "IP 地址或范围: " REMOVED_IP
                                if [ -z "$REMOVED_IP" ]; then
                                        echo "错误：未提供 IP 地址。"
                                else
                                        remove_firewall_rule "$REMOVED_IP"
                                fi
                                ;;
                        4)
                                nfs_client_mount
                                ;;
                        0)
                                echo "退出菜单。"
                                break
                                ;;
                        *)
                                echo "无效选择，请重新输入。"
                                ;;
                esac
                pause
        done
}
