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

deploy_phpmyadmin() {
    echo "开始部署 phpMyAdmin..."
    read -p "请输入 MySQL 数据库的 IP 地址或主机名（例如 127.0.0.1 或 mydb.example.com）: " MYSQL_HOST

    # 部署 phpMyAdmin 服务，不再通过环境变量设置上传大小
    docker run -d --name phpmyadmin \
        -e PMA_HOST=$MYSQL_HOST \
        -e PMA_ARBITRARY=1 \
        -p 8080:80 \
        --restart unless-stopped \
        phpmyadmin || { echo "phpMyAdmin 部署失败"; exit 1; }

    # 获取容器 ID
    PHP_CONTAINER_ID=$(docker ps -q -f "name=phpmyadmin")

    # 进入容器并检查配置文件是否存在
    echo "正在修改上传限制..."
    docker exec -it $PHP_CONTAINER_ID bash -c "
        # 检查配置文件是否存在，如果不存在则创建
        if [ ! -f /usr/local/etc/php/conf.d/uploads.ini ]; then
            touch /usr/local/etc/php/conf.d/uploads.ini;
        fi

        # 修改上传文件大小限制
        echo 'upload_max_filesize = 10G' >> /usr/local/etc/php/conf.d/uploads.ini;
        echo 'post_max_size = 10G' >> /usr/local/etc/php/conf.d/uploads.ini;"

    # 重启容器以使更改生效
    docker restart phpmyadmin

    # 获取本机公网 IP
    local public_ip=$(get_public_ip)
    echo "phpMyAdmin 部署完成！请访问以下地址："
    echo "  - URL: http://${public_ip}:8080"
    echo "  - 目标数据库: ${MYSQL_HOST}"

    pause
}

# 部署 Nginx Proxy Manager
deploy_nginx() {
    echo "开始部署 Nginx Proxy Manager..."
    mkdir -p /root/data /root/letsencrypt
    docker run -d --name nginx \
        --network host \
        -v /root/data:/data \
        -v /root/letsencrypt:/etc/letsencrypt \
        --restart unless-stopped jc21/nginx-proxy-manager || { echo "Nginx 部署失败"; exit 1; }

    # 获取本机公网 IP
    local public_ip=$(get_public_ip)
    echo "Nginx Proxy Manager 部署完成！请访问 http://${public_ip}:81 进行管理"
    
    pause
}

# 部署 MySQL 服务
deploy_mysql() {
    echo "开始部署 MySQL..."
    read -p "请输入 MySQL root 密码: " MYSQL_ROOT_PASSWORD
    mkdir -p /root/mysql/data /root/mysql/conf
    docker run -d --name mysql \
        -p 3306:3306 \
        -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
        -v /root/mysql/data:/var/lib/mysql \
        -v /root/mysql/conf:/etc/mysql/conf.d \
        --restart unless-stopped mysql:5.7 || { echo "MySQL 部署失败"; exit 1; }

    # 获取本机公网 IP
    local public_ip=$(get_public_ip)
    echo "MySQL 部署完成！请使用以下信息连接："
    echo "  - 公网 IP: ${public_ip}"
    echo "  - 端口: 3306"
    echo "  - root 密码: ${MYSQL_ROOT_PASSWORD}"

    pause
}

# 部署 Redis 服务
deploy_redis() {
    echo "开始部署 Redis..."
    read -p "请输入 Redis 密码: " REDIS_PASSWORD
    mkdir -p /root/redis
    docker run -d --name redis \
        -p 6379:6379 \
        --restart always \
        -v /root/redis:/data \
        redis:latest \
        redis-server --save 60 1 --loglevel warning --requirepass "$REDIS_PASSWORD" || { echo "Redis 部署失败"; exit 1; }

    # 获取本机公网 IP
    local public_ip=$(get_public_ip)
    echo "Redis 部署完成！请使用以下信息连接："
    echo "  - 公网 IP: ${public_ip}"
    echo "  - 端口: 6379"
    echo "  - 密码: ${REDIS_PASSWORD}"

    pause
}

# 修改生产环境部署菜单，添加 phpMyAdmin 选项
production_deployment_menu() {
    while true; do
        clear
        echo "==============================="
        echo "    生产环境部署功能菜单       "
        echo "==============================="
        echo "1. 部署 Nginx Proxy Manager"
        echo "2. 部署 MySQL"
        echo "3. 部署 Redis"
        echo "4. 部署 phpMyAdmin"
        echo "5. 返回主菜单"
        echo "==============================="
        read -p "请选择一个选项 (1-5): " choice

        case $choice in
            1) deploy_nginx ;;        # 部署 Nginx 服务
            2) deploy_mysql ;;        # 部署 MySQL 服务
            3) deploy_redis ;;        # 部署 Redis 服务
            4) deploy_phpmyadmin ;;   # 部署 phpMyAdmin 服务
            5) return ;;              # 返回主菜单
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
    done
}


# 暂停等待用户操作
pause() {
    read -p "按 Enter 键继续..."
}
