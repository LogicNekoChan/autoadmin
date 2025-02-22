#!/bin/bash

# 获取公共IP的函数
get_public_ip() {
    public_ip=$(curl -s4 ifconfig.me)
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s6 ifconfig.me)
    fi
    echo "$public_ip"
}

# 下载并解析 Docker Compose YAML 文件，提取容器名称
get_container_names() {
    # 下载docker-compose.yaml文件
    curl -s -o docker_compose.yaml https://raw.githubusercontent.com/LogicNekoChan/autoadmin/refs/heads/main/env_setup/daliy.yaml

    # 将 YAML 转换为 JSON，再用 jq 解析服务名称
    container_names=$(python3 -c 'import yaml, json, sys; print(json.dumps(yaml.safe_load(sys.stdin.read())))' < docker_compose.yaml | jq -r '.services | keys[]')

    if [ -z "$container_names" ]; then
        echo "没有找到容器服务!"
        exit 1
    fi

    echo "$container_names"
}

# 部署选定的容器
deploy_service() {
    local service_name=$1

    # 获取服务的docker-compose配置
    docker_compose_file=$(python3 -c 'import yaml, json, sys; print(json.dumps(yaml.safe_load(sys.stdin.read())))' < docker_compose.yaml | jq -r ".services.\"$service_name\"")

    # 临时文件创建并过滤错误格式的volumes
    echo "$docker_compose_file" | jq 'del(.volumes) | .volumes = []' > temp_docker_compose.yml

    # 使用docker-compose部署服务
    docker-compose -f temp_docker_compose.yml up -d

    if [ $? -eq 0 ]; then
        echo "$service_name 服务已部署，访问地址：http://$(get_public_ip)"
    else
        echo "$service_name 服务部署失败！" >&2
    fi

    # 清理临时文件
    rm -f temp_docker_compose.yml
}

# 显示容器服务列表
show_services_list() {
    echo "==============================="
    echo "请选择要部署的容器："
    container_names=$(get_container_names)
    IFS=$'\n' read -rd '' -a container_array <<< "$container_names"
    for i in "${!container_array[@]}"; do
        echo "$((i + 1)). ${container_array[i]}"
    done
    echo "==============================="
}

# 部署服务主函数
daily_service_deployment_menu() {
    while true; do
        clear
        show_services_list
        read -p "请输入容器的序号 (或输入 0 退出): " service_choice

        if [[ "$service_choice" == "0" ]]; then
            echo "退出部署菜单"
            break
        elif [[ "$service_choice" =~ ^[0-9]+$ ]] && [ "$service_choice" -ge 1 ] && [ "$service_choice" -le ${#container_array[@]} ]; then
            deploy_service "${container_array[$((service_choice - 1))]}"
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
