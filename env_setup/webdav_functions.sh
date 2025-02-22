#!/bin/bash

# WebDAV 功能模块

# 检查 rclone 是否安装
check_rclone() {
    if ! command -v rclone &>/dev/null; then
        echo "rclone 未安装，正在安装..."
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y rclone
        elif command -v yum &>/dev/null; then
            sudo yum install -y rclone
        else
            echo "未能检测到支持的包管理器，请手动安装 rclone。"
            exit 1
        fi
    fi
}

# 配置 WebDAV
configure_webdav() {
    echo "开始配置 WebDAV..."
    read -p "请输入 WebDAV 名称 (例如: my_webdav): " webdav_name
    read -p "请输入 WebDAV 地址 (例如: https://example.com/dav): " webdav_url
    read -p "请输入用户名: " webdav_user
    read -s -p "请输入密码: " webdav_pass
    echo

    rclone config create "$webdav_name" webdav url "$webdav_url" vendor other user "$webdav_user" pass "$webdav_pass"

    if [ $? -eq 0 ]; then
        echo "WebDAV 配置成功，名称为: $webdav_name"
    else
        echo "WebDAV 配置失败，请重试。"
    fi
    pause
}

# 删除 WebDAV 配置
delete_webdav_config() {
    echo "正在列出所有 WebDAV 配置..."
    rclone config show | grep -A 1 "type = webdav" | grep "name" | awk '{print NR, $3}' # 列出所有 WebDAV 配置名称及其序号

    # 获取所有 WebDAV 配置名称
    webdav_configs=$(rclone config show | grep -A 1 "type = webdav" | grep "name" | awk '{print $3}')
    
    # 检查是否有配置
    if [ -z "$webdav_configs" ]; then
        echo "没有找到任何 WebDAV 配置。"
        pause
        return
    fi

    read -p "请输入要删除的 WebDAV 配置序号: " config_index

    # 获取要删除的配置名称
    webdav_name=$(echo "$webdav_configs" | sed -n "${config_index}p")

    if [ -z "$webdav_name" ]; then
        echo "无效的序号，请重试。"
        pause
        return
    fi

    echo "正在删除 WebDAV 配置 $webdav_name..."
    rclone config delete "$webdav_name"

    if [ $? -eq 0 ]; then
        echo "WebDAV 配置 $webdav_name 已成功删除。"
    else
        echo "删除配置失败，请检查名称是否正确。"
    fi
    pause
}

# 挂载 WebDAV
mount_webdav() {
    read -p "请输入要挂载的 WebDAV 名称: " webdav_name
    read -p "请输入挂载路径 (本地文件夹): " mount_path

    if [ ! -d "$mount_path" ]; then
        echo "挂载路径不存在，正在创建..."
        mkdir -p "$mount_path"
    fi

    echo "正在挂载 WebDAV..."
    rclone mount "$webdav_name": "$mount_path" --daemon

    if [ $? -eq 0 ]; then
        echo "WebDAV 挂载成功，挂载路径为: $mount_path"
    else
        echo "WebDAV 挂载失败，请检查配置和路径。"
    fi
    pause
}

# 取消挂载 WebDAV
unmount_webdav() {
    read -p "请输入要取消挂载的路径: " mount_path
    echo "正在取消挂载..."
    fusermount -u "$mount_path" 2>/dev/null || umount "$mount_path" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "取消挂载成功：$mount_path"
    else
        echo "取消挂载失败，请检查路径或挂载状态。"
    fi
    pause
}

# 上传文件到 WebDAV
upload_to_webdav() {
    read -p "请输入要上传的文件路径: " file_path
    read -p "请输入目标 WebDAV 名称: " webdav_name
    read -p "请输入目标路径 (例如: /target_folder): " target_path

    if [ ! -f "$file_path" ]; then
        echo "文件不存在，请检查路径。"
        pause
        return
    fi

    echo "正在上传文件..."
    rclone copy "$file_path" "$webdav_name:$target_path"

    if [ $? -eq 0 ]; then
        echo "文件上传成功：$file_path -> $webdav_name:$target_path"
    else
        echo "文件上传失败，请检查路径和配置。"
    fi
    pause
}

# 查看挂载内容
list_webdav_content() {
    read -p "请输入要查看的 WebDAV 名称: " webdav_name
    read -p "请输入路径 (默认为根目录 /): " target_path
    target_path=${target_path:-/}

    echo "正在列出 WebDAV 内容..."
    rclone ls "$webdav_name:$target_path"

    if [ $? -ne 0 ]; then
        echo "查看内容失败，请检查路径和配置。"
    fi
    pause
}

# WebDAV 菜单
mount_webdav_menu() {
    check_rclone  # 检查 rclone 是否安装

    while true; do
        clear
        echo "==============================="
        echo "      WebDAV 管理菜单         "
        echo "==============================="
        echo "1. 配置新的 WebDAV"
        echo "2. 删除 WebDAV 配置"
        echo "3. 挂载 WebDAV"
        echo "4. 取消挂载 WebDAV"
        echo "5. 上传文件到 WebDAV"
        echo "6. 查看挂载内容"
        echo "7. 返回主菜单"
        echo "==============================="
        read -p "请选择一个选项 (1-7): " choice

        case $choice in
            1) configure_webdav ;;   # 配置新的 WebDAV
            2) delete_webdav_config ;; # 删除 WebDAV 配置
            3) mount_webdav ;;       # 挂载 WebDAV
            4) unmount_webdav ;;     # 取消挂载 WebDAV
            5) upload_to_webdav ;;   # 上传文件到 WebDAV
            6) list_webdav_content ;; # 查看挂载内容
            7) break ;;              # 返回主菜单
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
    done
}

# 暂停等待用户操作
pause() {
    read -p "按 Enter 键继续..."
}
