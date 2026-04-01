#!/bin/bash
set -e

echo "🛠️ 开始执行 DIY 预处理脚本..."

# 1. 预置 OpenClash 及 Meta 内核
mkdir -p package/lean
git clone --depth 1 https://github.com/vernesong/OpenClash.git package/lean/openclash

mkdir -p files/etc/openclash/core
cd files/etc/openclash/core
CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/v1.19.0/mihomo-linux-amd64-compatible.tar.gz"
# 主源失败自动走代理源
curl -L -o core.tar.gz "$CORE_URL" || curl -L -o core.tar.gz "https://gh-proxy.com/${CORE_URL}"
tar -xzf core.tar.gz mihomo-linux-amd64-compatible
mv mihomo-linux-amd64-compatible mihomo
chmod +x mihomo
rm -f core.tar.gz
cd ../../../../
echo "✅ OpenClash 及 Meta 内核 v1.19.0 预置完成"

# 2. 修改固件默认参数
# 主机名
sed -i "s|hostname='.*'|hostname='OpenWrt-25.12'|g" package/base-files/files/bin/config_generate
# 时区
sed -i "s|timezone='.*'|timezone='CST-8'|g" package/base-files/files/bin/config_generate
sed -i "/timezone='.*'/a\set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate
# LAN 默认 IP
sed -i "s|192.168.1.1|192.168.80.80|g" package/base-files/files/bin/config_generate

# 3. 兜底：确保基础 dnsmasq 不编译（防冲突）
sed -i 's/^CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/' .config 2>/dev/null || true

echo "✅ DIY 脚本执行完毕"
