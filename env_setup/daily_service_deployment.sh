#!/bin/bash

# 获取公共 IP 地址
get_public_ip() {
    ip addr show eth0 | grep inet | awk '{print $2}' | cut -d/ -f1
}

# 暂停功能
pause() {
    read -p "按任意键继续..."
}

# 部署 Minecraft 服务器
deploy_mcserver() {
    echo "部署 Minecraft 服务器..."
    docker run -d --name mcserver -e MEMORYSIZE=1G -e PAPERMC_FLAGS= -p 25565:25565 -v mcserver_data:/data marctv/minecraft-papermc-server:latest
    echo "Minecraft 服务器已部署，访问地址：$(get_public_ip):25565"
    pause
}

# 部署文件浏览器
deploy_filebrowser() {
    echo "部署文件浏览器..."
    docker run -d --name filebrowser -p 8090:80 -v filebrowser_data:/data -e DATA_DIR=/ -e TZ=Asia/Shanghai -e USERNAME=admin -e PASSWORD=admin123 filebrowser/filebrowser
    echo "文件浏览器已部署，访问地址：http://$(get_public_ip):8090"
    pause
}

# 部署 ChatGPT Web
deploy_chatgpt_web() {
    echo "部署 ChatGPT Web..."
    docker run -d --name chatgpt_web -p 8000:8000 -e ACCESS_TOKEN=your_access_token chatgptweb/chatgpt-web:latest
    echo "ChatGPT Web 服务已部署，访问地址：http://$(get_public_ip):8000"
    pause
}

# 部署 aaPanel
deploy_aapanel() {
    echo "部署 aaPanel..."
    docker run -d --name aapanel --network host -v website_data:/www/wwwroot -v mysql_data:/www/server/data -v vhost:/www/server/panel/vhost aapanel/aapanel:lnmp
    echo "aaPanel 面板管理工具已部署，访问地址：http://$(get_public_ip)"
    pause
}

# 部署 Calibre Web
deploy_calibre_web() {
    echo "部署 Calibre Web..."
    docker run -d --name calibre-web -p 8083:8083 -v calibre_web_data:/config -v calibre_library:/books lscr.io/linuxserver/calibre-web
    echo "Calibre Web 服务已部署，访问地址：http://$(get_public_ip):8083"
    pause
}

# 部署 KodBox 文件管理工具
deploy_kodbox() {
    echo "部署 KodBox 文件管理工具..."
    docker run -d --name kodbox -p 89:80 -v kodbox_data:/var/www/html kodcloud/kodbox
    echo "KodBox 文件管理工具已部署，访问地址：http://$(get_public_ip):89"
    pause
}

# 部署 Nginx Proxy Manager
deploy_nginx_proxy_manager() {
    echo "部署 Nginx Proxy Manager..."
    docker run -d --name nginx --network host -v nginx_data:/data -v letsencrypt:/etc/letsencrypt jc21/nginx-proxy-manager
    echo "Nginx Proxy Manager 已部署，访问地址：http://$(get_public_ip)"
    pause
}

# 部署 Vaultwarden
deploy_vaultwarden() {
    echo "部署 Vaultwarden..."
    docker run -d --name vaultwarden -p 86:80 -e DATABASE_URL=mysql://bitwarden:your_password@host:5432/bitwarden -v vaultwarden_data:/data vaultwarden/server:latest
    echo "Vaultwarden 服务已部署，访问地址：http://$(get_public_ip):86"
    pause
}

# 部署 Pi-hole
deploy_pihole() {
    echo "部署 Pi-hole..."
    docker run -d --name pihole -p 53:53 -p 53:53/udp -p 80:80 -v pihole_data:/etc/pihole -v dnsmasq_data:/etc/dnsmasq.d --env-file ./pihole.env --restart=unless-stopped pihole/pihole
    echo "Pi-hole 服务已部署，访问地址：http://$(get_public_ip)/admin"
    pause
}

# 部署 MySQL
deploy_mysql() {
    echo "部署 MySQL..."
    docker run -d --name mysql -e MYSQL_ROOT_PASSWORD=rootpassword -v mysql_data:/var/lib/mysql -p 3306:3306 mysql:latest
    echo "MySQL 服务已部署，访问地址：$(get_public_ip):3306"
    pause
}

# 部署 PostgreSQL
deploy_postgresql() {
    echo "部署 PostgreSQL..."
    docker run -d --name postgres -e POSTGRES_PASSWORD=rootpassword -v postgres_data:/var/lib/postgresql/data -p 5432:5432 postgres:latest
    echo "PostgreSQL 服务已部署，访问地址：$(get_public_ip):5432"
    pause
}

# 部署 Redis
deploy_redis() {
    echo "部署 Redis..."
    docker run -d --name redis -p 6379:6379 redis:latest
    echo "Redis 服务已部署，访问地址：$(get_public_ip):6379"
    pause
}

# 部署 Nextcloud
deploy_nextcloud() {
    echo "部署 Nextcloud..."
    docker run -d --name nextcloud -p 8080:80 -v nextcloud_data:/var/www/html nextcloud
    echo "Nextcloud 服务已部署，访问地址：http://$(get_public_ip):8080"
    pause
}

# 选择部署的服务
daily_service_deployment_menu() {
    echo "请选择要部署的服务:"
    echo "1. Minecraft 服务器"
    echo "2. 文件浏览器"
    echo "3. ChatGPT Web"
    echo "4. aaPanel"
    echo "5. Calibre Web"
    echo "6. KodBox"
    echo "7. Nginx Proxy Manager"
    echo "8. Vaultwarden"
    echo "9. Pi-hole"
    echo "10. MySQL"
    echo "11. PostgreSQL"
    echo "12. Redis"
    echo "13. Nextcloud"
    read -p "请输入选项数字: " choice

    case $choice in
        1) deploy_mcserver ;;
        2) deploy_filebrowser ;;
        3) deploy_chatgpt_web ;;
        4) deploy_aapanel ;;
        5) deploy_calibre_web ;;
        6) deploy_kodbox ;;
        7) deploy_nginx_proxy_manager ;;
        8) deploy_vaultwarden ;;
        9) deploy_pihole ;;
        10) deploy_mysql ;;
        11) deploy_postgresql ;;
        12) deploy_redis ;;
        13) deploy_nextcloud ;;
        *) echo "无效选项";;
    esac
}
