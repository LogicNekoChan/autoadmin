#!/bin/bash

# 引用 functions.sh、docker_functions.sh 和 crontab.sh 等文件
. ./env_setup/functions.sh
. ./env_setup/docker_functions.sh
. ./env_setup/crontab.sh
. ./env_setup/vpn_functions.sh
. ./env_setup/webdav_functions.sh
. ./env_setup/port_forwarding.sh 
. ./env_setup/production_setup.sh
# . ./env_setup/daily_service_deployment.sh   # 注释掉原有的引用行，我们将内容直接复制进来
. ./env_setup/deploy_docker_swarm_and_nfs.sh

#### 日常服务部署脚本开始 ####
#  复制粘贴 daily_service_deployment.sh 的全部内容到这里

# 定义 docker-compose.yaml 文件的 URL
DOCKER_COMPOSE_URL="https://raw.githubusercontent.com/LogicNekoChan/autoadmin/refs/heads/main/env_setup/docker_compose.yaml"

# 下载 docker-compose.yaml 文件到本地
download_docker_compose_config() {
    echo "正在下载 docker-compose 配置文件..."
    if curl -sSfLo docker-compose.yaml "$DOCKER_COMPOSE_URL"; then
        echo "docker-compose 配置文件下载成功。"
        return 0
    else
        echo "docker-compose 配置文件下载失败，请检查网络连接或 URL 是否正确。" >&2
        return 1
    fi
}

# 获取服务列表
get_services_from_compose() {
    if ! command -v docker compose >/dev/null 2>&1; then
        echo "请先安装 Docker Compose。" >&2
        return 1
    fi

    if ! download_docker_compose_config; then
        return 1
    fi

    # 从 docker-compose.yaml 文件中提取服务名称
    services_yaml=$(docker compose config --services 2>/dev/null)
    if [ -z "$services_yaml" ]; then
        echo "无法从 docker-compose.yaml 文件中获取服务列表，请检查文件内容。" >&2
        return 1
    fi

    # 将服务名称按行读取到数组
    services=()
    while IFS= read -r service; do
        services+=("$service")
    done <<< "$services_yaml"

    # 检查服务列表是否为空
    if [ ${#services[@]} -eq 0 ]; then
        echo "docker-compose.yaml 文件中未定义任何服务。" >&2
        return 1
    fi

    return 0
}

get_public_ip() {
    # 尝试获取IPv4地址
    public_ip=$(curl -s4 ifconfig.me)

    # 如果获取不到IPv4地址，再尝试获取IPv6地址
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s6 ifconfig.me)
    fi

    echo "$public_ip"
}

# 部署服务函数 (简化版本，移除 case 语句)
deploy_service() {
    local service_index=$1

    # 获取选中的服务名称
    service_name="${services[$((service_index - 1))]}"
    echo "您选择的服务是: $service_name"

    if ! command -v docker compose >/dev/null 2>&1; then
        echo "请先安装 Docker Compose。" >&2
        return 1
    fi

    if ! download_docker_compose_config; then
        return 1
    fi

    docker compose up -d "$service_name"
    echo "$service_name 服务已部署，访问地址请参考 docker-compose.yaml 文件中的端口配置。"
    pause
}

# 显示服务列表
show_services_list() {
    if get_services_from_compose; then
        echo "==============================="
        echo "请选择要部署的服务："
        for i in "${!services[@]}"; do
            echo "$((i + 1)). ${services[i]}"
        done
        echo "==============================="
    else
        echo "无法获取服务列表，请检查错误信息。" >&2
        return 1
    fi
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

# 检查是否安装 docker compose
if ! command -v docker compose >/dev/null 2>&1; then
    echo "请先安装 Docker Compose，本脚本依赖 Docker Compose v2 版本。" >&2
    exit 1
fi
