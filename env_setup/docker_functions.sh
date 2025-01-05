#!/bin/bash

# 查看所有容器
list_all_containers() {
    echo "正在列出所有容器..."
    containers=($(docker ps -a -q))
    if [ ${#containers[@]} -eq 0 ]; then
        echo "没有找到任何容器。"
        return
    fi

    for i in "${!containers[@]}"; do
        container_id="${containers[i]}"
        container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's/^\///')  # 获取容器名称
        echo "$((i + 1)). ID: $container_id 名称: $container_name"
    done
    pause
}

# 管理容器：启动、停止、删除
manage_docker_container() {
    action=$1  # 获取操作：start、stop 或 remove
    echo "请选择要操作的容器："
    containers=($(docker ps -a -q))
    if [ ${#containers[@]} -eq 0 ]; then
        echo "没有找到任何容器。"
        return
    fi

    # 列出所有容器供选择
    for i in "${!containers[@]}"; do
        container_id="${containers[i]}"
        container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's/^\///')
        echo "$((i + 1)). ID: $container_id 名称: $container_name"
    done

    read -p "请输入容器序号: " container_index
    if ! [[ "$container_index" =~ ^[0-9]+$ ]] || [ "$container_index" -le 0 ] || [ "$container_index" -gt ${#containers[@]} ]; then
        echo "无效的选择，请重新选择。"
        return
    fi

    container_id="${containers[$((container_index - 1))]}"

    case $action in
        start)
            echo "正在启动容器 $container_name (ID: $container_id)..."
            docker start "$container_id" || echo "启动失败。"
            ;;
        stop)
            echo "正在停止容器 $container_name (ID: $container_id)..."
            docker stop "$container_id" || echo "停止失败。"
            ;;
        remove)
            # 停止容器
            echo "正在停止容器 $container_name (ID: $container_id)..."
            docker stop "$container_id" || { echo "停止容器失败。"; return; }

            # 获取挂载的目录和卷信息
            echo "正在列出容器的挂载目录和卷..."
            mounts=$(docker inspect "$container_id" | jq -r '.[].Mounts[] | select(.Type=="bind") | .Source')
            volumes=$(docker inspect "$container_id" | jq -r '.[].Mounts[] | select(.Type=="volume") | .Name')

            # 删除挂载的目录
            for mount in $mounts; do
                if [ -d "$mount" ]; then
                    echo "正在删除挂载目录：$mount"
                    rm -rf "$mount" || echo "删除目录 $mount 失败。"
                fi
            done

            # 删除挂载的卷
            for volume in $volumes; do
                echo "正在删除卷：$volume"
                docker volume rm "$volume" || echo "删除卷 $volume 失败。"
            done

            # 删除容器
            echo "正在删除容器 $container_name (ID: $container_id)..."
            docker rm "$container_id" || echo "删除容器失败。"
            ;;
        *)
            echo "无效的操作。"
            ;;
    esac
    pause
}

# 备份容器映射卷到 WebDAV
backup_container_to_webdav() {
    check_rclone_installed || exit 1

    echo "请选择要备份的容器："
    containers=($(docker ps -a -q))
    if [ ${#containers[@]} -eq 0 ]; then
        echo "没有找到任何容器。"
        exit 1
    fi

    # 列出所有容器
    for i in "${!containers[@]}"; do
        container_id="${containers[i]}"
        container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's/^\///')
        echo "$((i + 1)). ID: $container_id 名称: $container_name"
    done

    read -p "请输入要备份的容器序号: " container_index
    if ! [[ "$container_index" =~ ^[0-9]+$ ]] || [ "$container_index" -le 0 ] || [ "$container_index" -gt ${#containers[@]} ]; then
        echo "无效的选择，请重试。"
        exit 1
    fi

    container_id="${containers[$((container_index - 1))]}"

    # 获取容器的挂载目录和卷
    echo "正在列出容器的挂载信息..."
    mounts=$(docker inspect "$container_id" | jq -r '.[].Mounts[] | select(.Type=="bind" or .Type=="volume") | .Source')
    if [ -z "$mounts" ]; then
        echo "容器没有映射的目录或卷"
        exit 1
    fi

    # WebDAV 备份路径
    read -p "请输入 WebDAV 备份路径 (例如 /backup/): " webdav_path

    # 获取容器名称和当前时间
    container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's/^\///')  # 获取容器名称
    backup_time=$(date +%Y%m%d%H%M%S)

    # 创建备份脚本并备份映射卷
    for mount_dir in $mounts; do
        if [ -d "$mount_dir" ]; then
            echo "正在备份目录 $mount_dir 到 WebDAV..."
            rclone copy "$mount_dir" "$WEBDAV_REMOTE:$webdav_path/${container_name}_$backup_time" --progress || {
                echo "备份失败，请检查网络或配置。"
                exit 1
            }
            echo "备份完成：$mount_dir -> $WEBDAV_REMOTE:$webdav_path/${container_name}_$backup_time"
        fi
    done
}

# 恢复容器的映射卷
restore_container_from_backup() {
    BACKUP_DIR="/root/backup"  # 备份路径

    echo "正在列出备份文件..."

    # 列出备份文件
    backups=($(ls $BACKUP_DIR/*.tar.gz 2>/dev/null))
    if [ ${#backups[@]} -eq 0 ]; then
        echo "没有找到备份文件。"
        exit 1
    fi

    # 显示备份文件供选择
    for i in "${!backups[@]}"; do
        backup_file="${backups[i]}"
        echo "$((i + 1)). $backup_file"
    done

    read -p "请输入备份文件序号: " backup_index
    if ! [[ "$backup_index" =~ ^[0-9]+$ ]] || [ "$backup_index" -le 0 ] || [ "$backup_index" -gt ${#backups[@]} ]; then
        echo "无效的选择，请重试。"
        exit 1
    fi

    selected_backup="${backups[$((backup_index - 1))]}"
    echo "您选择的备份文件是：$selected_backup"

    # 获取容器挂载的卷
    echo "正在恢复容器映射卷数据..."
    # 恢复挂载卷的逻辑
    tar -xzvf "$selected_backup" -C /  # 解压到指定目录
    echo "容器的映射卷数据已恢复。"
}

# 检查 rclone 是否安装
check_rclone_installed() {
    if ! command -v rclone &>/dev/null; then
        echo "rclone 未安装，请先安装 rclone。"
        return 1
    fi
    return 0
}

# 暂停函数
pause() {
    read -p "按任意键继续..."
}
