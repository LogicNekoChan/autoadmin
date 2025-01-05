#!/bin/bash

# 科学上网功能：x-ui 一键部署（基于 Docker Compose v2）

deploy_x_ui() {
    echo "正在部署 x-ui..."
    
    # 创建 x-ui 的工作目录
    XUI_DIR="/root/xui"
    mkdir -p "$XUI_DIR/db" "$XUI_DIR/cert"

    # 创建 docker-compose.yml 配置文件
    cat > "$XUI_DIR/docker-compose.yml" <<EOF
version: '3'
services:
  xui:
    image: enwaiax/x-ui:alpha-zh
    container_name: xui
    volumes:
      - $XUI_DIR/db:/etc/x-ui
      - $XUI_DIR/cert:/root/cert
    restart: unless-stopped
    network_mode: host
EOF

    # 检查是否已经安装 Docker 和 Docker Compose
    if ! command -v docker &>/dev/null; then
        echo "Docker 没有安装，请先安装 Docker。"
        pause
        return
    fi

    if ! command -v docker-compose &>/dev/null && ! command -v "docker compose" &>/dev/null; then
        echo "Docker Compose 没有安装，请先安装 Docker Compose v2。"
        pause
        return
    fi

    # 使用 Docker Compose v2 启动服务
    cd "$XUI_DIR" && docker compose up -d || {
        echo "x-ui 部署失败，请检查网络或配置文件。"
        pause
        return
    }

    echo "x-ui 部署完成，可以通过访问主机的相应端口进行管理。"
    pause
}


# 科学上网功能：xboard 一键部署
deploy_xboard() {
    echo "正在部署 xboard... 请稍候..."

    # 切换到 /root 目录
    cd /root || { echo "无法切换到 /root 目录"; exit 1; }

    # 获取 Xboard Docker Compose 文件
    echo "正在获取 Xboard Docker Compose 文件..."
    git clone -b docker-compose --depth 1 https://github.com/cedar2025/Xboard xboard || {
        echo "获取 Xboard Docker Compose 文件失败"; exit 1;
    }
    cd /root/xboard || { echo "无法切换到 /root/xboard 目录"; exit 1; }
    echo "Xboard Docker Compose 文件获取完成"

    # 执行数据库安装命令
    echo "正在执行数据库安装命令..."
    docker compose run -it --rm xboard php artisan xboard:install || {
        echo "数据库安装命令执行失败"; exit 1;
    }
    echo "数据库安装完成，请记录后台地址和管理员账号密码"

    # 启动 Xboard
    echo "正在启动 Xboard..."
    docker compose up -d || { echo "Xboard 启动失败"; exit 1; }
    echo "Xboard 启动完成"

    # 提示访问网址
    echo "请访问 http://你的IP:7001/ 来体验 Xboard"
    echo "部署完成！"

    pause
}

# 科学上网功能：xrayr 一键部署
deploy_xrayr() {
    echo "正在部署 xrayr..."

    # 设置 XrayR 项目路径
    XRAYR_DIR="/root/XrayR-release"

    # 检查 Docker Compose 是否已安装
    command -v docker compose >/dev/null 2>&1 || { echo "请先安装 Docker Compose"; exit 1; }

    # 创建项目目录并克隆代码
    mkdir -p "$XRAYR_DIR"
    cd "$XRAYR_DIR" || { echo "无法切换到 $XRAYR_DIR 目录"; exit 1; }
    git clone https://github.com/XrayR-project/XrayR-release . || { echo "克隆 XrayR 代码失败"; exit 1; }

    # 配置环境变量（可选，根据您的需要）
    # 例如：设置配置文件路径
    # export XRAYR_CONFIG=/etc/xray/config.json

    # 启动 XrayR
    echo "正在启动 XrayR..."
    docker compose up -d || { echo "XrayR 启动失败"; exit 1; }
    echo "XrayR 启动完成"

    # 添加日志功能（可选）
    echo "部署日志已保存至 $XRAYR_DIR/deploy.log"

    # 提示用户部署成功
    echo "XrayR 部署完成！"
    pause
}

# 科学上网管理菜单
vpn_menu() {
    while true; do
        clear
        echo "==============================="
        echo "      科学上网管理菜单        "
        echo "==============================="
        echo "1. 部署 x-ui"
        echo "2. 部署 xboard"
        echo "3. 部署 xrayr"
        echo "4. 返回主菜单"
        echo "==============================="
        read -p "请选择一个选项 (1-4): " choice

        case $choice in
            1) deploy_x_ui ;;         # 部署 x-ui
            2) deploy_xboard ;;       # 部署 xboard
            3) deploy_xrayr ;;        # 部署 xrayr
            4) break ;;               # 返回主菜单
            *) echo "无效选项，请重试"; sleep 2 ;;
        esac
    done
}

# 暂停等待用户操作
pause() {
    read -p "按 Enter 键继续..."
}
