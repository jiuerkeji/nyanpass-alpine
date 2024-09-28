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

if [ "$PRODUCT_ARGUMENTS" = "update" ]; then
    if [ -z "$BG_UPDATE" ]; then
        BG_UPDATE=1 sh "$0" "$1" "$2" >/dev/null 2>&1 &
        exit
    fi
fi

#### 判断处理器架构
case $(uname -m) in
aarch64 | arm64) ARCH=arm64 ;;
x86_64 | amd64) ARCH=amd64 ;;
*) error "cpu not supported" ;;
esac

PRODUCT="${PRODUCT_EXE}_linux_${ARCH}"

#### 重复安装检查

echo_uninstall() {
    echo "rc-service $1 stop ; rc-update del $1 ; rm -rf /opt/$1 ; rm -f /etc/init.d/$1"
}

echo_uninstall_to_file() {
    echo "rc-service $1 stop ; rc-update del $1 ; rm -rf /opt/$1 ; rm -f /etc/init.d/$1" >"$2"
}

#### 询问用户

if [ -z "$S" ]; then
    if [ -z "$BG_UPDATE" ]; then
        read -p "请输入服务名 [默认 nyanpass] : " service_name
        service_name=$(echo "$service_name" | awk '{print$1}')
        if [ -z "$service_name" ]; then
            service_name="nyanpass"
        fi
        if [ -f "/etc/init.d/${service_name}" ]; then
            hint "该服务已经存在，请先运行以下命令卸载："
            echo_uninstall "$service_name"
            exit
        fi
        read -p "是否优化系统参数 [输入 任意内容 不优化，默认优化] : " youhua
        youhua=$(echo "$youhua" | awk '{print$1}')
        if [ -z "$youhua" ]; then
            OPTIMIZE=1
        fi
        read -p "是否安装常用工具 [输入 任意内容 不安装，默认安装] : " azcygj
        azcygj=$(echo "$azcygj" | awk '{print$1}')
        if [ -z "$azcygj" ]; then
            INSTALL_TOOLS=1
        fi
    else
        service_name=$(basename "$PWD")
    fi
else
    service_name="$S"
fi

#### 检查重复对接
if [ -z "$BG_UPDATE" ]; then
    nyaUUID=$(echo "$PRODUCT_ARGUMENTS" | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}' || true)
    if [ -n "$nyaUUID" ]; then
        nyaFiles=$(find /opt -name "start.sh" -exec grep -l "$nyaUUID" {} \; || true)
        if [ -n "$nyaFiles" ]; then
            warning "检测到重复对接，会影响正常运行。参考信息如下："
            echo "$nyaFiles"
            error "请卸载上述服务，再进行对接。"
        fi
    fi

    mkdir -p /etc/init.d
    mkdir -p ~/.config
    mkdir -p /opt/"${service_name}"
    cd /opt/"${service_name}"

    #### 安装一些常用工具
    if [ -n "$INSTALL_TOOLS" ]; then
        apk update
        apk add --no-cache wget curl mtr iftop unzip htop net-tools bind-tools nload psmisc nano screen
    fi
fi

#### Download & unzip

rm -rf temp_backup
mkdir -p temp_backup

if [ -z "$NO_DOWNLOAD" ]; then
    mv "$PRODUCT_EXE" temp_backup/ || true
    curl -fLSsO "$DOWNLOAD_HOST"/download/download.sh || true
    sh download.sh "$DOWNLOAD_HOST" "$PRODUCT" || true
fi

if [ -f "$PRODUCT_EXE" ]; then
    rm -rf temp_backup
else
    mv temp_backup/* . || true
    error "下载失败！"
fi

#### Install

if [ -z "$BG_UPDATE" ]; then
    rm -f start.sh
    echo 'source ./env.sh || true' >>start.sh
    echo "./$PRODUCT_EXE $PRODUCT_ARGUMENTS" >>start.sh
fi

# 创建 OpenRC 服务文件
echo "#!/sbin/openrc-run
description=\"nyanpass\"

command=\"/bin/sh\"
command_args=\"/opt/${service_name}/start.sh\"
command_background=true

depend() {
    need net
}" > /etc/init.d/"${service_name}"

chmod +x /etc/init.d/"${service_name}"
rc-update add "${service_name}" default
rc-service "${service_name}" start

info "安装成功"
info "如需卸载，请运行以下命令："
echo_uninstall "$service_name"

UNINSTALL_FILE="/opt/${service_name}.uninstall.sh"
echo_uninstall_to_file "$service_name" "$UNINSTALL_FILE"
info "或者："
echo "sh $UNINSTALL_FILE"

if [ -n "$BG_UPDATE" ]; then
    if [ -n "$NYP_DOCKER" ]; then
        kill -9 1
    fi
fi

#### 系统参数优化

if [ -n "$OPTIMIZE" ]; then
    info "正在优化系统参数..."
    echo '
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

net.ipv4.conf.all.rp_filter = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_frto = 0
net.ipv4.tcp_mtu_probing = 0
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 2
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.core.somaxconn = 4096
net.ipv4.tcp_abort_on_overflow = 1

vm.swappiness = 10
fs.file-max = 6553560
' >/etc/sysctl.conf
    sysctl -p
fi

info "当前 TCP 阻控算法: $(cat /proc/sys/net/ipv4/tcp_congestion_control)"
