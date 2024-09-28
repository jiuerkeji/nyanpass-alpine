#!/bin/sh
set -e

warning() { echo -e "\033[31m\033[01m$*\033[0m"; }
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; }
info() { echo -e "\033[32m\033[01m$*\033[0m"; }
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }

if [ -z "$DOWNLOAD_HOST" ]; then
    DOWNLOAD_HOST="https://api.nyafw.com"
fi

PRODUCT_EXE="$1"
PRODUCT_ARGUMENTS="$2"

case $PRODUCT_EXE in
rel_nodeclient) true ;;
*) error "输入有误" ;;
esac

if [ -z "$PRODUCT_ARGUMENTS" ]; then
    error "输入有误"
fi

#### 判断处理器架构

case $(uname -m) in
aarch64 | arm64) ARCH=arm64 ;;
x86_64 | amd64) ARCH=amd64 ;;
*) error "cpu not supported" ;;
esac

PRODUCT="$PRODUCT_EXE"_linux_"$ARCH"

#### Installation preparation

if [ -z "$S" ]; then
    read -p "请输入服务名 [默认 nyanpass] : " service_name
    service_name=$(echo "$service_name" | awk '{print$1}')
    service_name=${service_name:-nyanpass}
else
    service_name="$S"
fi

#### Check if service exists

service_dir="/etc/init.d/${service_name}"
if [ -f "${service_dir}" ]; then
    hint "该服务已经存在，请先运行以下命令卸载："
    echo "rc-service ${service_name} stop && rc-update del ${service_name} default && rm -f ${service_dir}"
    exit
fi

#### Install necessary tools

apk update
apk add wget curl mtr-ifconfig iftop unzip htop net-tools bind-tools

#### Download and prepare

mkdir -p /opt/"${service_name}"
cd /opt/"${service_name}"
curl -fLSsO "$DOWNLOAD_HOST"/download/download.sh
sh download.sh "$DOWNLOAD_HOST" "$PRODUCT"

#### Create start script

echo '#!/bin/sh
source ./env.sh || true
./'"$PRODUCT_EXE" "$PRODUCT_ARGUMENTS" > start.sh

chmod +x start.sh

#### Create service script

echo '#!/sbin/openrc-run
command="/opt/'"${service_name}"'/start.sh"
command_background=true
pidfile="/run/'"${service_name}"'.pid"
start_stop_daemon_args="--background --make-pidfile"
depend() {
    need net
}
' > "${service_dir}"

chmod +x "${service_dir}"
rc-update add "${service_name}" default
rc-service "${service_name}" start

info "安装成功"
info "如需卸载，请运行以下命令："
echo "rc-service ${service_name} stop && rc-update del ${service_name} default && rm -f ${service_dir}"

echo
