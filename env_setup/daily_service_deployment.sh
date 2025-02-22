#!/bin/bash
set -euo pipefail

# 定义 Docker Compose 文件 URL 及本地文件名，方便后续维护
COMPOSE_URL="https://raw.githubusercontent.com/LogicNekoChan/autoadmin/refs/heads/main/env_setup/daliy.yaml"
COMPOSE_FILE="docker_compose.yaml"

# 检查依赖工具是否存在
check_dependencies() {
    for cmd in curl python3 jq docker-compose; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "错误: 缺少必需的工具: $cmd" >&2
            exit 1
        fi
    done
}
check_dependencies

# 获取公共IP地址，优先 IPv4，若获取失败则尝试 IPv6
get_public_ip() {
    local public_ip
    public_ip=$(curl -s4 ifconfig.me)
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s6 ifconfig.me)
    fi
    echo "$public_ip"
}

# 下载 Docker Compose YAML 文件，并解析服务名称
get_container_names() {
    if ! curl -s -o "$COMPOSE_FILE" "$COMPOSE_URL"; then
        echo "下载 Docker Compose 文件失败!" >&2
        exit 1
    fi

    # 利用 python3 将 YAML 转为 JSON，再用 jq 提取 services 下的 key
    local names
    names=$(python3 -c 'import yaml, json, sys; print(json.dumps(yaml.safe_load(sys.stdin.read())))' < "$COMPOSE_FILE" | jq -r '.services | keys[]')
    if [ -z "$names" ]; then
        echo "没有找到容器服务!" >&2
        exit 1
    fi
    echo "$names"
}

# 全局数组存储服务名称
declare -a container_array

# 显示容器服务列表，并将名称存入全局数组 container_array
show_services_list() {
    echo "==============================="
    echo "请选择要部署的容器："
    local names
    names=$(get_container_names)
    # 使用 mapfile 将每一行写入数组
    mapfile -t container_array <<< "$names"
    for i in "${!container_array[@]}"; do
        echo "$((i + 1)). ${container_array[i]}"
    done
    echo "==============================="
}

# 部署选定的容器服务
deploy_service() {
    local service_name=$1

    # 提取指定服务的配置
    local service_config
    service_config=$(python3 -c "import yaml, json, sys; config=yaml.safe_load(sys.stdin.read()); print(json.dumps(config.get('services', {}).get('$service_name', {})))" < "$COMPOSE_FILE")
    if [ -z "$service_config" ] || [ "$service_config" = "null" ]; then
        echo "未找到服务 $service_name 的配置" >&2
        return 1
    fi

    # 处理 volumes 部分：删除原有 volumes 字段，并设为空数组（根据原逻辑处理）
    echo "$service_config" | jq 'del(.volumes) | .volumes = []' > temp_docker_compose.yml

    if docker-compose -f temp_docker_compose.yml up -d; then
        echo "$service_name 服务已部署，访问地址：http://$(get_public_ip)"
    else
        echo "$service_name 服务部署失败！" >&2
    fi

    rm -f temp_docker_compose.yml
}

# 主菜单，循环等待用户选择部署容器
daily_service_deployment_menu() {
    while true; do
        clear
        show_services_list
        read -rp "请输入容器的序号 (或输入 0 退出): " service_choice

        if [[ "$service_choice" == "0" ]]; then
            echo "退出部署菜单"
            break
        elif [[ "$service_choice" =~ ^[0-9]+$ ]] && [ "$service_choice" -ge 1 ] && [ "$service_choice" -le "${#container_array[@]}" ]; then
            deploy_service "${container_array[$((service_choice - 1))]}"
        else
            echo "无效选择，请重新输入"
        fi
        sleep 2
    done
}

