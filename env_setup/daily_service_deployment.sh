#!/bin/bash

get_public_ip() {
    # 尝试获取IPv4地址
    public_ip=$(curl -s4 ifconfig.me)

    # 如果获取不到IPv4地址，再尝试获取IPv6地址
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s6 ifconfig.me)
    fi

    echo "$public_ip"
}

# 服务容器的配置
services=(
    "AdGuardHome - 广告过滤器"
    "Alist - 文件管理工具"
    "Calibre Web - 电子书管理工具"
    "qBittorrent - 下载工具"
    "Qinglong - 自动化脚本"
    "Vaultwarden - 密码管理"
    "Photoprism - 照片管理工具"
    "Vocechat - 聊天工具"
    "WordPress - 网站"
    "Synctv - 文件同步"
    "Portainer - 容器管理工具"
)

# 部署服务函数
deploy_service() {
    local service_index=$1

    # 获取选中的服务名称
    service_name="${services[$((service_index - 1))]}"
    echo "您选择的服务是: $service_name"

    case "$service_name" in
        "AdGuardHome - 广告过滤器")
            docker run -d --name adguardhome -p 53:53 -p 3000:3000 adguard/adguardhome
            echo "AdGuardHome 服务已部署，访问地址：http://$(get_public_ip):3000"
            pause
            ;;
        "Alist - 文件管理工具")
            MAPPED_DIR="/root/alist/"
            mkdir -p "$MAPPED_DIR"

            # 提示用户输入数据库连接信息
            echo "请输入数据库连接信息："
            read -p "数据库地址（默认：localhost）： " DB_HOST
            DB_HOST=${DB_HOST:-localhost}

            read -p "数据库端口（默认：3306）： " DB_PORT
            DB_PORT=${DB_PORT:-3306}

            read -p "数据库用户名（默认：root）： " DB_USER
            DB_USER=${DB_USER:-root}

            read -sp "数据库密码： " DB_PASS
            echo
            read -p "数据库名称（默认：alist）： " DB_NAME
            DB_NAME=${DB_NAME:-alist}

            # 启动 Alist 容器
            docker run -d --name alist -p 5244:5244 -p 6800:6800 -v "$MAPPED_DIR:/opt/alist/data" xhofe/alist
            if [ $? -eq 0 ]; then
                echo "Alist 服务已部署，访问地址：http://$(get_public_ip):5244"
            else
                echo "Alist 服务部署失败！" >&2
                return 1
            fi

            # 确认容器正在运行
            while ! docker ps -q -f name=alist; do
                echo "容器启动中，请稍等..."
                sleep 5
            done

            # 等待容器中的配置文件生成
            CONFIG_FILE="$MAPPED_DIR/config.json"
            echo "等待配置文件生成..."
            while [ ! -f "$CONFIG_FILE" ]; do
                echo "配置文件尚未生成，等待 10 秒..."
                sleep 10
            done

            echo "配置文件已找到，正在修改配置文件..."

            # 修改配置文件
            jq ".database.type=\"mysql\" |
                .database.host=\"$DB_HOST\" |
                .database.port=$DB_PORT |
                .database.user=\"$DB_USER\" |
                .database.password=\"$DB_PASS\" |
                .database.name=\"$DB_NAME\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" \
            && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            echo "配置文件修改完成。"

            # 重启容器以应用新配置
            echo "正在重启容器以应用新的配置..."
            docker restart alist
            echo "容器已重启，服务已更新。"

            pause
            ;;
        "Calibre Web - 电子书管理工具")
            docker run -d --name calibre-web -p 8083:8083 lscr.io/linuxserver/calibre-web
            if [ $? -eq 0 ]; then
                echo "Calibre Web 服务已部署，访问地址：http://$(get_public_ip):8083"
            else
                echo "Calibre Web 服务部署失败！" >&2
            fi
            pause
            ;;
        "qBittorrent - 下载工具")
            docker run -d --name qbittorrent -p 8080:8080 -p 6881:6881 lscr.io/linuxserver/qbittorrent
            echo "qBittorrent 服务已部署，访问地址：http://$(get_public_ip):8080"
            pause
            ;;
        "Qinglong - 自动化脚本")
            docker run -d --name qinglong -p 5700:5700 whyour/qinglong
            echo "Qinglong 服务已部署，访问地址：http://$(get_public_ip):5700"
            pause
            ;;
        "Vaultwarden - 密码管理")
            # 提示用户输入数据库连接信息
            echo "请输入数据库连接信息："
            read -p "数据库地址（默认：localhost）： " DB_HOST
            DB_HOST=${DB_HOST:-localhost}

            read -p "数据库端口（默认：3306）： " DB_PORT
            DB_PORT=${DB_PORT:-3306}

            read -p "数据库用户名（默认：root）： " DB_USER
            DB_USER=${DB_USER:-root}

            read -sp "数据库密码： " DB_PASS
            echo

            read -p "数据库名称（默认：vaultwarden）： " DB_NAME
            DB_NAME=${DB_NAME:-vaultwarden}

            # 创建 Vaultwarden 容器，并设置环境变量连接数据库
            docker run -d \
                --name vaultwarden \
                -p 86:80 \
                -e DATABASE_URL="mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME" \
                vaultwarden/server:latest

            # 检查容器是否启动成功
            if [ $? -eq 0 ]; then
                echo "Vaultwarden 服务已部署，访问地址：http://$(get_public_ip):86"
            else
                echo "Vaultwarden 服务部署失败！" >&2
            fi

            pause
            ;;
        "Photoprism - 照片管理工具")
            docker run -d --name photoprism -p 2342:2342 photoprism/photoprism
            echo "Photoprism 服务已部署，访问地址：http://$(get_public_ip):2342"
            pause
            ;;
        "Vocechat - 聊天工具")
            docker run -d --name vocechat -p 3019:3000 privoce/vocechat-server:latest
            echo "Vocechat 服务已部署，访问地址：http://$(get_public_ip):3019"
            pause
            ;;
        "WordPress - 网站")
            docker run -d --name wordpress -p 8089:80 wordpress
            echo "WordPress 服务已部署，访问地址：http://$(get_public_ip):8089"
            pause
            ;;
        "Synctv - 文件同步")
            docker run -d --name synctv -p 8092:8080 synctvorg/synctv:latest
            echo "Synctv 服务已部署，访问地址：http://$(get_public_ip):8092"
            pause
            ;;
        "Portainer - 容器管理工具")
            docker run -d \
                -p 9000:9000 \
                -p 8000:8000 \
                --restart always \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v /opt/docker/portainer-ce/data:/data \
                --name portainer-ce portainer/portainer-ce
            echo "Portainer 服务已部署，访问地址：http://$(get_public_ip):9000"
            pause
            ;;
        *)
            echo "未知服务，请重新选择。" >&2
            ;;
    esac
}

# 显示服务列表
show_services_list() {
    echo "==============================="
    echo "请选择要部署的服务："
    for i in "${!services[@]}"; do
        echo "$((i + 1)). ${services[i]}"
    done
    echo "==============================="
}

# 部署服务主函数
daily_service_deployment_menu() {
    while true; do
        clear
        show_services_list
        read -p "请输入服务的序号 (或输入 0 退出): " service_choice

        if [[ "$service_choice" == "0" ]]; then
            echo "退出部署菜单"
            break
        elif [[ "$service_choice" =~ ^[0-9]+$ ]] && [ "$service_choice" -ge 1 ] && [ "$service_choice" -le ${#services[@]} ]; then
            deploy_service "$service_choice"
        else
            echo "无效选择，请重新输入"
        fi
        sleep 2
    done
}

# 暂停等待用户按键
pause() {
    read -p "按 Enter 键继续..."
}
