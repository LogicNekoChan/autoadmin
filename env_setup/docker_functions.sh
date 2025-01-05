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

            # 删除容器挂载的卷
            echo "正在列出容器的卷挂载..."
            container_volumes=$(docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{end}}{{end}}' "$container_id")

            if [ -z "$container_volumes" ]; then
                echo "该容器没有挂载卷。"
            else
                for volume in $container_volumes; do
                    # 删除挂载卷
                    echo "正在删除卷：$volume"
                    docker volume rm "$volume" || echo "删除卷 $volume 失败。"
                done
            fi

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

# 手动备份容器卷到本地
backup_container_to_local() {
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

    # 获取容器的挂载卷
    echo "正在列出容器的挂载卷..."
    container_volumes=$(docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{end}}{{end}}' "$container_id")

    if [ -z "$container_volumes" ]; then
        echo "该容器没有挂载卷。"
        exit 1
    fi

    # 本地备份路径
    BACKUP_DIR="/root/backup"

    # 执行备份
    for volume in $container_volumes; do
        echo "正在备份卷 $volume 到本地备份目录..."
        backup_file="$BACKUP_DIR/$(basename $volume)_$(date +\%Y\%m\%d).tar.gz"
        docker run --rm -v "$volume:/volume" -v "$BACKUP_DIR:/backup" alpine \
            tar -czf "/backup/$(basename $volume)_$(date +\%Y\%m\%d).tar.gz" -C /volume . || echo "备份卷 $volume 失败。"
    done

    echo "备份完成！"
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo "请选择操作:"
        echo "1. 查看所有容器"
        echo "2. 管理容器（启动/停止/删除）"
        echo "3. 手动备份容器卷"
        echo "4. 退出"
        read -p "请输入选项 [1-4]: " choice

        case $choice in
            1) list_all_containers ;;
            2) 
                echo "请选择操作："
                echo "1. 启动容器"
                echo "2. 停止容器"
                echo "3. 删除容器"
                read -p "请输入操作 [1-3]: " action
                case $action in
                    1) manage_docker_container "start" ;;
                    2) manage_docker_container "stop" ;;
                    3) manage_docker_container "remove" ;;
                    *) echo "无效的选择";;
                esac
                ;;
            3) backup_container_to_local ;;
            4) exit 0 ;;
            *) echo "无效的选择，请重新选择";;
        esac
    done
}

