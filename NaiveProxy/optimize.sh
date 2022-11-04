#!/usr/bin/env bash
echo=echo
for cmd in echo /bin/echo; do
    $cmd >/dev/null 2>&1 || continue

    if ! $cmd -e "" | grep -qE '^-e'; then
        echo=$cmd
        break
    fi
done

CSI=$($echo -e "\033[")
CEND="${CSI}0m"
CDGREEN="${CSI}32m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CMAGENTA="${CSI}1;35m"
CCYAN="${CSI}1;36m"

OUT_ALERT() {
    echo -e "${CYELLOW} $1 ${CEND}"
}

OUT_ERROR() {
    echo -e "${CRED} $1 ${CEND}"
}

OUT_INFO() {
    echo -e "${CCYAN} $1 ${CEND}"
}

if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -q -E -i "debian|raspbian"; then
    release="debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -q -E -i "raspbian|debian"; then
    release="debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
else
    OUT_ERROR "[错误] 不支持的操作系统！"
    exit 1
fi

OUT_ALERT "[信息] 正在更新系统中！"
if [[ ${release} == "centos" ]]; then
    yum makecache
    yum install epel-release -y
    yum update -y
else
    apt update
    apt dist-upgrade -y
    apt autoremove --purge -y
fi

OUT_ALERT "[信息] 正在安装 haveged 增强性能中！"
if [[ ${release} == "centos" ]]; then
    yum install haveged -y
else
    apt install haveged -y
fi

OUT_ALERT "[信息] 正在配置 haveged 增强性能中！"
systemctl disable haveged
systemctl enable haveged
systemctl restart haveged

OUT_ALERT "[信息] 正在优化系统参数中！"
cat > /etc/sysctl.conf << EOF
vm.swappiness = 10
fs.file-max = 1000000
net.ipv4.ip_forward = 1
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog=30000
net.ipv4.tcp_mtu_probing = 1
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_thin_linear_timeouts = 1
net.ipv4.tcp_fastopen = 3
net.core.somaxconn = 2048
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_syn_backlog = 16384
EOF
cat > /etc/security/limits.conf << EOF
* soft nofile 512000
* hard nofile 512000
* soft nproc 512000
* hard nproc 512000
root soft nofile 512000
root hard nofile 512000
root soft nproc 512000
root hard nproc 512000
EOF
cat > /etc/systemd/journald.conf <<EOF
[Journal]
SystemMaxUse=384M
SystemMaxFileSize=128M
ForwardToSyslog=no
EOF
sysctl -p

cat > /etc/systemd/system/nettune.service << EOF
[Unit]
After=network.service
[Service]
Type=oneshot
ExecStart=/usr/share/nettune.sh
[Install]
WantedBy=multi-user.target
EOF

cat > /usr/share/nettune.sh << EOF
#!/bin/bash
ip r c `ip r|head -n1` initcwnd 10000 initrwnd 10000
EOF

chmod +x /usr/share/nettune.sh
systemctl enable --now nettune

OUT_INFO "[信息] 优化完毕！"
exit 0