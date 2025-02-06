#!/bin/bash

# 引用各个功能文件并初始化环境变量
. ./env_setup/functions.sh
. ./env_setup/docker_functions.sh
. ./env_setup/crontab.sh
. ./env_setup/vpn_functions.sh
. ./env_setup/webdav_functions.sh
. ./env_setup/port_forwarding.sh
. ./env_setup/production_setup.sh
. ./env_setup/daily_service_deployment.sh   # 引用日常服务部署脚本
. ./env_setup/deploy_docker_swarm_and_nfs.sh

# 定义显示主菜单的函数，带有颜色和美观设计
show_main_menu() {
    clear
    echo "================================================================"
    echo -e "\033[1;36m系统管理脚本\033[0m"
    echo "================================================================"
    
    echo -e "\n \033[1;32m功能列表\033[0m:"
    echo "1. 系统维护 (\033[1;31m高亮\033[0m)"
    echo "2. Docker 管理 (\033[1;34m蓝色\033[0m)"
    echo "3. Cron 任务管理 (\033[1;32m绿色\033[0m)"
    echo "4. WebDAV 挂载 (\033[1;35m紫色\033[0m)"
    echo "5. 科学上网管理 (\033[1;31m红色高亮\033[0m)"
    echo "6. 内网端口转发 (\033[1;33m黄色\033[0m)"
    echo "7. 生产环境部署 (\033[1;36m蓝色背景\033[0m)"
    echo "8. 日常服务部署 (\033[1;32m绿色高亮\033[0m)"
    echo "9. 集群部署 (\033[1;34m深蓝色\033[0m)"
    echo "10. 退出 (\033[1;31m红色高亮\033[0m)"
    echo "================================================================"
    
    select_menu_option
}

# 定义菜单选择函数，处理输入并显示相关信息
select_menu_option() {
    local choice
    while true; do
        echo -e "\n请根据数字选择功能（1-10）:"
        read -p "你的选择是：" choice
        
        case $choice in
            1) echo -e "\033[1;31m进入 系统维护 \033[0m"; system_maintenance_menu ;;
            2) echo -e "\033[1;34m进入 Docker 管理 \033[0m"; show_docker_menu ;;
            3) echo -e "\033[1;32m进入 Cron 任务管理 \033[0m"; cron_task_menu ;;
            4) echo -e "\033[1;35m进入 WebDAV 挂载 \033[0m"; mount_webdav_menu ;;
            5) echo -e "\033[1;31m进入 科学上网管理 \033[0m"; vpn_menu ;;
            6) echo -e "\033[1;33m进入 内网端口转发管理 \033[0m"; port_forwarding_menu ;;
            7) echo -e "\033[1;36m进入 生产环境部署 \033[0m"; production_deployment_menu ;;
            8) echo -e "\033[1;32m进入 日常服务部署 \033[0m"; daily_service_deployment_menu ;;
            9) echo -e "\033[1;34m进入 Docker-Swarm 集群部署 \033[0m"; deploy_docker_swarm_and_nfs_menu ;;
            10) echo -e "\033[1;31m退出脚本\033[0m"; exit 0 ;;
            *) echo -e "无效选项，请重试（按Enter输入）"; sleep 2; break ;;
        esac
    done
}

# 显示主菜单，用户可以选择相应的操作
show_main_menu

# 提供脚本信息
echo -e "\n\033[1;36m关于该脚本\033[0m"
echo -e "----------------------------------------"
echo -e "版本：v1.2.0"
echo -e "日期：2025年2月6日"
echo -e "功能：全面的服务器系统管理脚本，支持多种操作场景"
echo -e "说明：请仔细阅读每个选项的描述，确保使用正确"
echo -e "----------------------------------------\033[0m"

# 开始执行主循环
show_main_menu
