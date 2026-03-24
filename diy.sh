#!/bin/bash
# ============================================================
# OpenWrt x86-64 固件 DIY 脚本
# 基于 OpenWrt Official 最新稳定版源码编译
# 作者: zhuyihua12
# ============================================================

# ---- 更新 Feeds ----
echo "========== 更新 Feeds =========="
sed -i 's|https://downloads.openwrt.org|https://mirrors.vsean.net/openwrt|g' feeds.conf.default
# 添加 ImmortalWrt 源以获取更多 LuCI 插件（含 OpenClash）
cat >> feeds.conf.default << 'EOF'
src-git immortalwrt https://github.com/immortalwrt/packages.git;openwrt-25.12
src-git immortalwrt_luci https://github.com/immortalwrt/luci.git;openwrt-25.12
EOF

./scripts/feeds update -a
./scripts/feeds install -a

# ---- 自定义网络配置 ----
echo "========== 自定义网络配置 =========="

# 修改默认 LAN IP 为 192.168.80.80
cat > files/etc/config/network << 'NETWORK'
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix 'fd00::/8'

config device
	option name 'br-lan'
	option type 'bridge'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '192.168.80.80'
	option netmask '255.255.255.0'
	option ip6assign '60'

config interface 'wan'
	option device 'eth0'
	option proto 'dhcp'

config interface 'wan6'
	option device 'eth0'
	option proto 'dhcpv6'
NETWORK

# 关闭 IPv6 - 通过 sysctl
cat > files/etc/sysctl.conf << 'SYSCTL'
# 关闭 IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.br-lan.disable_ipv6 = 1
net.ipv6.conf.eth0.disable_ipv6 = 1
SYSCTL

# 关闭 IPv6 防火墙
cat > files/etc/firewall.user << 'FIREWALL'
# 关闭 IPv6
ip6tables -F
ip6tables -X
ip6tables -P INPUT DROP
ip6tables -P OUTPUT DROP
ip6tables -P FORWARD DROP

# 零信任：安全 SSH
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j DROP
FIREWALL

# 修改主机名
cat > files/etc/config/system << 'SYSTEM'
config system
	option hostname 'OpenWrt-25.12'
	option timezone 'CST-8'
	option zonename 'Asia/Shanghai'
	option ttylogin '0'
	option log_size '64'
	option urandom_seed '0'

config timeserver 'ntp'
	option enabled '1'
	option server '0.cn.pool.ntp.org 1.cn.pool.ntp.org 2.cn.pool.ntp.org 3.cn.pool.ntp.org'
SYSTEM

# ---- 修复 Dnsmasq 冲突 ----
echo "========== 修复 Dnsmasq 冲突 =========="
# OpenClash 依赖 dnsmasq-full，移除默认 dnsmasq
rm -f package/feeds/packages/luci-app-openclash/depends/depends-dnsmasq-full

# ---- 下载 OpenClash Meta 内核 ----
echo "========== 下载 OpenClash Meta 内核 =========="
CLASH_META_URL="https://github.com/MetaCubeX/mihomo/releases/download/v1.19.0/mihomo-linux-amd64-v1.19.0.gz"
CLASH_CORE_DIR="files/etc/openclash/core"

mkdir -p "$CLASH_CORE_DIR"
if [ ! -f "${CLASH_CORE_DIR}/clash_meta" ]; then
    curl -L -o /tmp/clash_meta.gz "$CLASH_META_URL" 2>/dev/null
    if [ -f /tmp/clash_meta.gz ]; then
        gunzip -f /tmp/clash_meta.gz
        chmod +x /tmp/clash_meta
        mv /tmp/clash_meta "${CLASH_CORE_DIR}/clash_meta"
        echo "✅ Meta 内核下载成功"
    else
        echo "⚠️ Meta 内核下载失败，将使用 OpenClash 在线下载"
    fi
fi

# ---- 清理 ----
echo "========== 清理 =========="
rm -rf tmp/ logs/

echo "========== DIY 脚本执行完毕 =========="
