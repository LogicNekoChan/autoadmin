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
    container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's/^\///')

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

            # 删除容器挂载的目录
            echo "正在删除容器 $container_name (ID: $container_id)..."
            echo "正在列出容器的挂载目录..."
            mounts=$(docker inspect "$container_id" | jq -r '.[].Mounts[] | select(.Type=="bind") | .Source')
            
            # 删除挂载的目录
            for mount in $mounts; do
                if [ -d "$mount" ]; then
                    echo "正在删除挂载目录：$mount"
                    rm -rf "$mount" || echo "删除目录 $mount 失败。"
                fi
            done

            # 删除容器
            docker rm "$container_id" || echo "删除容器失败。"
            ;;
        *)
            echo "无效的操作。"
            ;;
    esac
    pause
}

# 设置定期备份
set_scheduled_backup() {
    # 确保 rclone 已安装
    check_rclone_installed || exit 1

    # 选择 WebDAV 配置
    choose_webdav_config || exit 1

    # 获取要备份的容器信息
    echo "请选择要设置定期备份的容器："
    containers=($(docker ps -a -q))
    if [ ${#containers[@]} -eq 0 ]; then
        echo "没有找到任何容器。"
        exit 1
    fi

    # 列出所有容器
    for i in "${!containers[@]}"; do
        container_id="${containers[i]}"
        container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's/^\///')  # 获取容器名称
        echo "$((i + 1)). ID: $container_id 名称: $container_name"
    done

    read -p "请输入要设置定期备份的容器序号: " container_index
    if ! [[ "$container_index" =~ ^[0-9]+$ ]] || [ "$container_index" -le 0 ] || [ "$container_index" -gt ${#containers[@]} ]; then
        echo "无效的选择，请重试。"
        exit 1
    fi

    container_id="${containers[$((container_index - 1))]}"

    # 获取容器的挂载目录
    echo "正在列出容器的挂载目录..."
    mounts=$(docker inspect "$container_id" | jq -r '.[].Mounts[] | select(.Type=="bind") | .Source')
    if [ -z "$mounts" ]; then
        echo "容器没有映射的目录"
        exit 1
    fi

    # WebDAV 备份路径
    read -p "请输入 WebDAV 备份路径 (例如 /backup/): " webdav_path

    # 配置 cron 任务
    echo "请选择备份频率："
    echo "1. 每天备份"
    echo "2. 每周备份"
    echo "3. 每月备份"
    read -p "请输入频率 (1-3): " frequency

    case $frequency in
        1) cron_schedule="0 0 * * *" ;;   # 每天备份
        2) cron_schedule="0 0 * * 0" ;;   # 每周备份
        3) cron_schedule="0 0 1 * *" ;;   # 每月备份
        *) echo "无效的选择。"; exit 1 ;;
    esac

    # 创建备份脚本
    backup_script="/root/backup_container_$container_id.sh"
    cat > "$backup_script" <<EOL
#!/bin/bash
# 备份容器的挂载目录到 WebDAV
rclone copy "$mounts" "$WEBDAV_REMOTE:$webdav_path" --progress || {
    echo "备份失败，请检查网络或配置。"
    exit 1
}
EOL

    # 给备份脚本赋予执行权限
    chmod +x "$backup_script"

    # 添加 cron 任务
    (crontab -l ; echo "$cron_schedule $backup_script") | crontab - || {
        echo "设置定期备份任务失败。"
        exit 1
    }

    echo "定期备份任务已设置成功。"
}

# 删除定期备份任务
delete_scheduled_backup() {
    # 获取所有的 cron 任务
    crontab -l > mycron
    if grep -q "backup_container" mycron; then
        # 删除备份任务相关的 cron 任务
        sed -i '/backup_container/d' mycron
        crontab mycron
        echo "定期备份任务已删除。"
    else
        echo "没有找到定期备份任务。"
    fi
    rm -f mycron
}

# WebDAV 配置路径
WEBDAV_CONFIG_PATH="/root/.config/rclone/rclone.conf"
WEBDAV_REMOTE="webdav_remote"  # 默认的 WebDAV 远程配置名称
BACKUP_DIR="/root/container_backup"  # 备份存放目录

# 确保备份目录存在
mkdir -p "$BACKUP_DIR"

# 检查 rclone 是否安装
check_rclone_installed() {
    if ! command -v rclone &> /dev/null; then
        echo "未检测到 rclone，请安装 rclone。"
        return 1
    fi
    echo "rclone 已安装"
    return 0
}

# 获取 WebDAV 配置
get_webdav_configs() {
    rclone config show | grep -i "webdav" -B 3
}

# 选择 WebDAV 配置
choose_webdav_config() {
    # 获取 WebDAV 配置
    webdav_configs=$(rclone config show | grep -i "webdav" -B 3 | grep "name" | awk '{print $2}')

    # 如果没有 WebDAV 配置
    if [ -z "$webdav_configs" ]; then
        echo "未检测到 WebDAV 配置，请创建 WebDAV 配置。"
        return 1
    fi

    # 如果只有一个 WebDAV 配置，直接使用该配置
    if [ $(echo "$webdav_configs" | wc -l) -eq 1 ]; then
        selected_config=$(echo "$webdav_configs" | head -n 1)
        echo "只有一个 WebDAV 配置，自动选择：$selected_config"
        WEBDAV_REMOTE="$selected_config"
        return 0
    fi

    # 如果有多个配置，提供交互式选择
    echo "检测到多个 WebDAV 配置，请选择一个："
    select config in $webdav_configs; do
        if [ -n "$config" ]; then
            WEBDAV_REMOTE="$config"
            echo "您选择的 WebDAV 配置是：$config"
            break
        else
            echo "无效的选择，请重新选择。"
        fi
    done
}

# 容器备份到 WebDAV
backup_container_to_webdav() {
    # 确保 rclone 已安装
    check_rclone_installed || exit 1

    # 选择 WebDAV 配置
    choose_webdav_config || exit 1

    # 获取要备份的容器信息
    echo "请选择要备份的容器："
    containers=($(docker ps -a -q))
    if [ ${#containers[@]} -eq 0 ]; then
        echo "没有找到任何容器。"
        exit 1
    fi

    # 列出所有容器
    for i in "${!containers[@]}"; do
        container_id="${containers[i]}"
        container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's/^\///')  # 获取容器名称
        echo "$((i + 1)). ID: $container_id 名称: $container_name"
    done

    read -p "请输入要备份的容器序号: " container_index
    if ! [[ "$container_index" =~ ^[0-9]+$ ]] || [ "$container_index" -le 0 ] || [ "$container_index" -gt ${#containers[@]} ]; then
        echo "无效的选择，请重试。"
        exit 1
    fi

    container_id="${containers[$((container_index - 1))]}"
    container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's/^\///')  # 获取容器名称
    echo "您选择的容器是：ID: $container_id 名称: $container_name"

    # 获取容器的挂载目录
    echo "正在列出容器的挂载目录..."
    mounts=$(docker inspect "$container_id" | jq -r '.[].Mounts[] | select(.Type=="bind") | .Source')
    if [ -z "$mounts" ]; then
        echo "容器没有映射的目录"
        exit 1
    fi

    # WebDAV 备份路径
    read -p "请输入 WebDAV 备份路径 (例如 /backup/): " webdav_path

    # 遍历所有挂载目录进行备份
    for mount_dir in $mounts; do
        if [ -d "$mount_dir" ]; then
            echo "正在备份目录 $mount_dir 到 WebDAV..."
            rclone copy "$mount_dir" "$WEBDAV_REMOTE:$webdav_path" --progress || {
                echo "备份失败，请检查网络或配置。"
                exit 1
            }
            echo "备份完成：$mount_dir -> $WEBDAV_REMOTE:$webdav_path"
        else
            echo "目录 $mount_dir 不存在，跳过备份。"
        fi
    done
}

# 恢复容器
restore_container_from_backup() {
    echo "正在列出备份文件..."

    # 列出备份文件
    backups=($(ls $BACKUP_DIR/*.tar.gz))
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

    # 获取正在运行的容器
    echo "正在列出正在运行的容器..."
    running_containers=($(docker ps -q))
    if [ ${#running_containers[@]} -eq 0 ]; then
        echo "没有正在运行的容器。"
        exit 1
    fi

    for i in "${!running_containers[@]}"; do
        container_id="${running_containers[i]}"
        container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's/^\///')
        echo "$((i + 1)). $container_name (ID: $container_id)"
    done

    read -p "请输入要恢复的容器序号: " container_index
    if ! [[ "$container_index" =~ ^[0-9]+$ ]] || [ "$container_index" -le 0 ] || [ "$container_index" -gt ${#running_containers[@]} ]; then
        echo "无效的选择，请重试。"
        exit 1
    fi

    container_id="${running_containers[$((container_index - 1))]}"
    container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's/^\///')
    echo "您选择的容器是：$container_name (ID: $container_id)"

    # 停止并删除容器挂载目录
    echo "正在停止容器 $container_name..."
    docker stop "$container_id" || exit 1

    echo "正在删除容器挂载目录..."
    mounts=$(docker inspect "$container_id" | jq -r '.[].Mounts[] | select(.Type=="bind") | .Source')
    for mount in $mounts; do
        if [ -d "$mount" ]; then
            rm -rf "$mount"
            echo "删除目录：$mount"
        fi
    done

    # 恢复容器
    echo "正在恢复容器 $container_name..."
    docker start "$container_id" || exit 1

    # 解压备份文件
    echo "正在解压备份文件 $selected_backup..."
    tar -xvzf "$selected_backup" -C "/var/lib/docker/volumes/$container_name/_data" || exit 1

    echo "恢复完成，容器已启动并恢复。"
}

# 主菜单
show_docker_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      Docker 管理菜单       "
        echo "==============================="
        echo "1. 查看所有容器"
        echo "2. 启动容器"
        echo "3. 停止容器"
        echo "4. 删除容器"
        echo "5. 容器立即备份到 WebDAV"
        echo "6. 设置定期备份"
        echo "7. 删除定期备份任务"
        echo "8. 恢复容器"
        echo "9. 退出"
        echo "==============================="
        read -p "请选择一个选项 (1-9): " docker_choice

        case $docker_choice in
            1) list_all_containers ;;
            2) manage_docker_container start ;;
            3) manage_docker_container stop ;;
            4) manage_docker_container remove ;;
            5) backup_container_to_webdav ;;
            6) set_scheduled_backup ;;
            7) delete_scheduled_backup ;;
            8) restore_container_from_backup ;;
            9) exit 0 ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done
}

# 暂停等待用户操作
pause() {
    read -p "按 Enter 键继续..."
}
