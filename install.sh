#!/bin/sh
set -e

# 替换不支持的选项
grep() {
    if command -v busybox >/dev/null 2>&1 && busybox grep -h 2>&1 | grep -q 'unrecognized option'; then
        # 使用 find + grep 组合替换
        find "$3" -type f -name "$2" -exec busybox grep -H "$1" {} +
    else
        command grep "$@"
    fi
}

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

if [ "$PRODUCT_ARGUMENTS" = "update" ]; then
    if [ -z "$BG_UPDATE" ]; then
        BG_UPDATE=1 sh "$0" "$1" "$2" >/dev/null 2>&1 &
        exit
    fi
fi

case $(uname -m) in
aarch64 | arm64) ARCH=arm64 ;;
x86_64 | amd64) [[ "$(awk -F ':' '/flags/{print $2; exit}' /proc/cpuinfo)" =~ avx2 ]] && ARCH=amd64v3 || ARCH=amd64 ;;
*) error "cpu not supported" ;;
esac

PRODUCT="$PRODUCT_EXE"_linux_"$ARCH"

echo_uninstall() {
    echo "rc-service $1 stop ; rc-update del $1; rm -rf /opt/$1 ; rm -f /etc/init.d/$1"
}

echo_uninstall_to_file() {
    echo "rc-service $1 stop ; rc-update del $1; rm -rf /opt/$1 ; rm -f /etc/init.d/$1" >"$2"
}

if [ -z "$S" ]; then
    if [ -z "$BG_UPDATE" ]; then
        read -p "请输入服务名 [默认 nyanpass] : " service_name
        service_name=$(echo "$service_name" | awk '{print$1}')
        if [ -z "$service_name" ];then
            service_name="nyanpass"
        fi
        if [ -f "/etc/init.d/${service_name}" ];then
            hint "该服务已经存在，请先卸载。"
            echo_uninstall "$service_name"
            exit
        fi
    else
        service_name=$(basename "$PWD")
    fi
else
    service_name="$S"
fi

if [ -z "$BG_UPDATE" ]; then
    mkdir -p /etc/init.d
    mkdir -p ~/.config
    mkdir -p /opt/"${service_name}"
    cd /opt/"${service_name}" || exit 1

    if [ -n "$INSTALL_TOOLS" ]; then
        apk update
        apk add --no-cache wget curl mtr iftop unzip htop net-tools bind-tools nload psmisc nano screen
    fi
fi

rm -rf temp_backup
mkdir -p temp_backup

if [ -z "$NO_DOWNLOAD" ]; then
    mv "$PRODUCT_EXE" temp_backup/ || true
    curl -fLSsO "$DOWNLOAD_HOST"/download/download.sh || { echo "下载 download.sh 失败"; exit 1; }
    sh download.sh "$DOWNLOAD_HOST" "$PRODUCT" || { echo "下载 $PRODUCT 失败"; exit 1; }
fi

if [ -f "$PRODUCT_EXE" ]; then
    rm -rf temp_backup
else
    mv temp_backup/* . || true
    error "下载失败！"
fi
