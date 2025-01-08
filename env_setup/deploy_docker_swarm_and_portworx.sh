deploy_docker_swarm_and_portworx_menu() {
    while true; do
        clear
        echo "==============================="
        echo "请选择要执行的操作："
        echo "1. 部署 Docker Swarm 集群"
        echo "2. 部署 Portworx 持久化存储"
        echo "3. 激活新子节点并为其部署持久化存储"
        echo "0. 退出"
        echo "==============================="
        read -p "请输入操作的序号 (1/2/3/0): " choice

        case "$choice" in
            1)
                deploy_docker_swarm
                ;;
            2)
                deploy_portworx_with_persistence
                ;;
            3)
                activate_new_node_with_persistence
                ;;
            0)
                echo "退出菜单"
                break
                ;;
            *)
                echo "无效选择，请重新输入"
                ;;
        esac
        sleep 2
    done
}

# 部署 Docker Swarm 集群
deploy_docker_swarm() {
    echo "正在部署 Docker Swarm 集群..."

    # 检查是否已经是 Docker Swarm 集群
    if docker info | grep -q "Swarm: active"; then
        echo "Docker Swarm 已经处于活动状态。"
        return
    fi

    # 初始化 Docker Swarm 集群
    docker swarm init --advertise-addr "$(get_public_ip)"
    if [ $? -eq 0 ]; then
        echo "Docker Swarm 集群已成功初始化。"
    else
        echo "Docker Swarm 初始化失败！" >&2
    fi
    pause
}

# 自动识别未挂载的存储设备
get_available_storage_device() {
    # 使用 lsblk 获取所有磁盘设备，并过滤出未挂载的设备
    for device in $(lsblk -d -n -p -o NAME,MOUNTPOINT | grep -v 'MOUNTPOINT' | awk '{print $1}'); do
        # 判断该磁盘是否未挂载
        if ! lsblk -o MOUNTPOINT "$device" | grep -q "/"; then
            # 返回第一个未挂载的设备
            echo "$device"
            return 0
        fi
    done
    # 如果没有未挂载的设备，返回空值
    echo ""
}

# 部署 Portworx 持久化存储服务
deploy_portworx_with_persistence() {
    echo "正在部署 Portworx 持久化存储..."

    # 检查是否为 Docker Swarm 环境
    if ! docker info | grep -q "Swarm: active"; then
        echo "Docker Swarm 未启用，请先启用 Docker Swarm。" >&2
        return 1
    fi

    # 获取节点的公网 IP 地址
    public_ip=$(get_public_ip)

    # 自动识别未挂载的存储设备
    STORAGE_DEVICE=$(get_available_storage_device)
    
    if [ -z "$STORAGE_DEVICE" ]; then
        echo "没有可用的存储设备，请确保系统有未挂载的磁盘。" >&2
        return 1
    fi

    echo "找到可用的存储设备: $STORAGE_DEVICE"

    # 检查是否已经有 Portworx 卷
    EXISTING_VOLUME=$(docker volume ls -q -f name=portworx_data)

    if [ -n "$EXISTING_VOLUME" ]; then
        echo "发现已有的 Portworx 卷: $EXISTING_VOLUME"
        # 使用已有的卷
        echo "将使用已有的 Portworx 卷，调整卷配置..."
    else
        # 配置 Portworx 持久化存储卷
        DATA_DIR="/opt/portworx-data"
        echo "没有发现现有的 Portworx 卷，创建新的卷: $DATA_DIR"
        
        # 创建新的持久化存储卷（可以为多个节点创建挂载点）
        mkdir -p $DATA_DIR
        docker volume create --name portworx_data -o type=none -o device=$DATA_DIR -o o=bind
    fi

    # 检查并创建日志目录
    LOG_DIR="/var/lib/osd/log"
    if [ ! -d "$LOG_DIR" ]; then
        echo "创建日志目录: $LOG_DIR"
        sudo mkdir -p $LOG_DIR
        sudo chmod 755 $LOG_DIR
    fi

    # 安装 Portworx OCI bundle（如果尚未安装）
    REL="/3.2"  # 更新为 Portworx 版本 3.2
    latest_stable=$(curl -fsSL "https://install.portworx.com$REL/?type=dock&stork=false&aut=false" | awk '/image: / {print $2}' | head -1)

    # 执行 px-runc 安装命令，指定集群ID，KVDB 和存储设备
    echo "正在安装 Portworx ..."

    sudo docker run --entrypoint /runc-entry-point.sh \
        --rm -i --privileged=true \
        -v /opt/pwx:/opt/pwx -v /etc/pwx:/etc/pwx \
        $latest_stable --upgrade

    if [ $? -ne 0 ]; then
        echo "Portworx OCI bundle 安装失败！" >&2
        return 1
    fi

    # 配置 Portworx 安装
    echo "正在配置 Portworx ..."

    # 使用本机的公网 IP 地址作为 etcd 地址
    local etcd_address="etcd://$public_ip:2379"

    # 如果存在卷，就跳过创建新卷并调整现有卷配置
    if [ -n "$EXISTING_VOLUME" ]; then
        echo "检测到已有的卷，开始调整卷的大小..."
        # 扩展卷大小
        sudo /opt/pwx/bin/pxctl volume expand --size 5Gi portworx_data
    else
        # 创建新卷并设置卷大小为 5GB
        sudo /opt/pwx/bin/px-runc install -c "mintcat" -k $etcd_address -s $STORAGE_DEVICE \
            --volume-size 5Gi  # 设置卷大小为 5GB
    fi

    if [ $? -ne 0 ]; then
        echo "Portworx 配置失败！" >&2
        return 1
    fi

    # 激活并启动 Portworx 服务
    echo "正在激活并启动 Portworx 服务..."
    sudo systemctl daemon-reload
    sudo systemctl enable portworx
    sudo systemctl start portworx

    if [ $? -eq 0 ]; then
        echo "Portworx 持久化存储服务已成功部署，您可以通过以下命令访问："
        echo "http://$public_ip:9001"
    else
        echo "Portworx 服务启动失败！" >&2
        return 1
    fi

    pause
}

# 激活新子节点并为其部署持久化存储
activate_new_node_with_persistence() {
    echo "正在激活新子节点并为其部署持久化存储..."

    # 检查是否为 Docker Swarm 环境
    if ! docker info | grep -q "Swarm: active"; then
        echo "Docker Swarm 未启用，请先启用 Docker Swarm。" >&2
        return 1
    fi

    # 获取主节点的 Swarm Join Token
    echo "请输入主节点的 Swarm Join Token（可通过主节点运行 docker swarm join-token worker 获取）："
    read -p "Swarm Join Token: " JOIN_TOKEN

    if [ -z "$JOIN_TOKEN" ]; then
        echo "无效的 Join Token" >&2
        return 1
    fi

    # 获取新节点的公网 IP 地址
    new_node_ip=$(get_public_ip)

    # 新节点加入 Docker Swarm 集群
    echo "正在将新节点加入 Swarm 集群..."
    docker swarm join --token "$JOIN_TOKEN" "$new_node_ip:2377"
    if [ $? -eq 0 ]; then
        echo "新节点已成功加入 Swarm 集群。"
    else
        echo "新节点加入 Swarm 集群失败！" >&2
        return 1
    fi

    # 激活新节点的持久化存储
    echo "正在为新节点激活持久化存储..."
    
    # 自动识别新节点的未挂载存储设备
    STORAGE_DEVICE=$(get_available_storage_device)

    if [ -z "$STORAGE_DEVICE" ]; then
        echo "没有可用的存储设备，请确保新节点有未挂载的磁盘。" >&2
        return 1
    fi

    echo "找到可用的存储设备: $STORAGE_DEVICE"
    
    # 配置 Portworx 持久化存储卷
    DATA_DIR="/opt/portworx-data"
    
    # 创建持久化存储卷
    mkdir -p $DATA_DIR
    sudo docker volume create --name portworx_data -o type=none -o device=$DATA_DIR -o o=bind

    # 配置 Portworx
    sudo /opt/pwx/bin/px-runc install -c mintcat \
        -k etcd://myetc.company.com:2379 \
        -s $STORAGE_DEVICE

    # 启动 Portworx
    sudo /opt/pwx/bin/px-runc start

    # 验证 Portworx 是否运行正常
    sudo /opt/pwx/bin/pxctl status

    if [ $? -eq 0 ]; then
        echo "Portworx 持久化存储服务已成功激活并为新节点部署。"
    else
        echo "Portworx 服务激活失败！" >&2
    fi
    pause
}

# 获取公网 IP
get_public_ip() {
    # 尝试获取IPv4地址
    public_ip=$(curl -s4 ifconfig.me)

    # 如果获取不到IPv4地址，再尝试获取IPv6地址
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s6 ifconfig.me)
    fi

    echo "$public_ip"
}

# 暂停功能
pause() {
    read -p "按 Enter 键继续..."
}
