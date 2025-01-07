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
    
    # 配置 Portworx 持久化存储卷
    DATA_DIR="/opt/portworx-data"
    
    # 创建持久化存储卷（可以为多个节点创建挂载点）
    mkdir -p $DATA_DIR
    docker volume create --name portworx_data -o type=none -o device=$DATA_DIR -o o=bind

    # 检查并创建日志目录
    LOG_DIR="/var/lib/osd/log"
    if [ ! -d "$LOG_DIR" ]; then
        echo "创建日志目录: $LOG_DIR"
        sudo mkdir -p $LOG_DIR
        sudo chmod 755 $LOG_DIR
    fi

    # 安装 Portworx OCI bundle（如果尚未安装）
    REL="/2.13"  # 版本号，确保使用你所需的版本
    latest_stable=$(curl -fsSL "https://install.portworx.com$REL/?type=dock&stork=false&aut=false" | awk '/image: / {print $2}' | head -1)

    # 执行 px-runc 安装命令，指定集群ID，KVDB 和存储设备
    echo "正在安装 Portworx ..."
    sudo docker run --entrypoint /runc-entry-point.sh \
        --rm -i --privileged=true \
        -v /opt/pwx:/opt/pwx -v /etc/pwx:/etc/pwx \
        $latest_stable

    if [ $? -ne 0 ]; then
        echo "Portworx OCI bundle 安装失败！" >&2
        return 1
    fi

    # 配置 Portworx 安装
    echo "正在配置 Portworx ..."
    sudo /opt/pwx/bin/px-runc install -c "mintcat" -k etcd://myetc.company.com:2379 -s $STORAGE_DEVICE

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
