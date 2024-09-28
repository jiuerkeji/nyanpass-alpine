#!/bin/sh

NZ_BASE_PATH="/opt/nezha"
NZ_DASHBOARD_PATH="${NZ_BASE_PATH}/dashboard"
NZ_AGENT_PATH="${NZ_BASE_PATH}/agent"
NZ_DASHBOARD_SERVICE="/etc/systemd/system/nezha-dashboard.service"
NZ_DASHBOARD_SERVICERC="/etc/init.d/nezha-dashboard"
NZ_VERSION="v0.19.0"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
export PATH=$PATH:/usr/local/bin

os_arch=""
[ -e /etc/os-release ] && grep -i "PRETTY_NAME" /etc/os-release | grep -qi "alpine" && os_alpine='1'

sudo() {
    # 判断是否为 Alpine 系统并检查 sudo 是否存在，如果不存在则直接执行命令
    if [ "$os_alpine" = 1 ]; then
        "$@"
    else
        myEUID=$(id -ru)
        if [ "$myEUID" -ne 0 ]; then
            if command -v sudo > /dev/null 2>&1; then
                command sudo "$@"
            else
                err "错误: 您的系统未安装 sudo，因此无法进行该项操作。"
                exit 1
            fi
        else
            "$@"
        fi
    fi
}

check_systemd() {
    # 对于 Alpine，不使用 systemd 检查
    if [ "$os_alpine" != 1 ] && ! command -v systemctl >/dev/null 2>&1; then
        echo "不支持此系统：未找到 systemctl 命令"
        exit 1
    fi
}

install_base() {
    # 使用 apk 作为包管理工具进行软件安装
    (command -v curl >/dev/null 2>&1 && command -v wget >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1) ||
        (command -v apk >/dev/null 2>&1 && sudo apk update && sudo apk add curl wget unzip)
}

install_dashboard_docker() {
    # 检查 Docker 是否已安装，如果未安装则在 Alpine 中安装 Docker
    if [ ! "$FRESH_INSTALL" = 0 ]; then
        command -v docker >/dev/null 2>&1
        if [ $? != 0 ]; then
            echo "正在安装 Docker"
            if [ "$os_alpine" = 1 ]; then
                sudo apk add docker docker-compose
                sudo rc-update add docker
                sudo rc-service docker start
            else
                curl -sL https://get.docker.com | sudo bash -s
                sudo systemctl enable docker.service
                sudo systemctl start docker.service
            fi
            printf "${green}Docker${plain} 安装成功\n"
            installation_check
        fi
    fi
}

restart_and_update_standalone() {
    # 修改为适用于 Alpine 的服务重启方式
    if [ "$os_alpine" = 1 ]; then
        sudo rc-service nezha-dashboard stop
        sudo rc-service nezha-dashboard start
    else
        sudo systemctl daemon-reload
        sudo systemctl stop nezha-dashboard
        sudo systemctl start nezha-dashboard
    fi
}

start_dashboard_standalone() {
    # 修改为适用于 Alpine 的服务启动方式
    if [ "$os_alpine" = 1 ]; then
        sudo rc-service nezha-dashboard start
    else
        sudo systemctl start nezha-dashboard
    fi
}

stop_dashboard_standalone() {
    # 修改为适用于 Alpine 的服务停止方式
    if [ "$os_alpine" = 1 ]; then
        sudo rc-service nezha-dashboard stop
    else
        sudo systemctl stop nezha-dashboard
    fi
}

uninstall_dashboard_standalone() {
    # 修改为适用于 Alpine 的服务卸载方式
    if [ "$os_alpine" = 1 ]; then
        sudo rc-update del nezha-dashboard
        sudo rc-service nezha-dashboard stop
    else
        sudo systemctl disable nezha-dashboard
        sudo systemctl stop nezha-dashboard
    fi

    sudo rm -rf $NZ_DASHBOARD_PATH
    if [ "$os_alpine" = 1 ]; then
        sudo rm $NZ_DASHBOARD_SERVICERC
    else
        sudo rm $NZ_DASHBOARD_SERVICE
    fi
}

show_agent_log() {
    # 在 Alpine 中查看日志
    if [ "$os_alpine" = 1 ]; then
        sudo tail -n 100 /var/log/nezha-agent.log
    else
        sudo journalctl -xf -u nezha-agent.service
    fi
}

show_dashboard_log_standalone() {
    # 在 Alpine 中查看日志
    if [ "$os_alpine" = 1 ]; then
        sudo tail -n 100 /var/log/nezha-dashboard.log
    else
        sudo journalctl -xf -u nezha-dashboard.service
    fi
}

# 剩余的部分代码根据具体需求进行相似的修改
