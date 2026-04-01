#!/bin/bash
set -e

echo "🛠️ 开始执行 DIY 预处理脚本..."

# 1. 预置 OpenClash 源码
mkdir -p package/lean
if [ ! -d "package/lean/openclash" ]; then
    echo "📥 正在克隆 OpenClash..."
    git clone --depth 1 https://github.com/vernesong/OpenClash.git package/lean/openclash
fi

# 2. 预置 Meta 内核 (Mihomo)
(
    CORE_DIR="files/etc/openclash/core"
    mkdir -p "$CORE_DIR"
    cd "$CORE_DIR"
    
    CORE_VER="v1.19.0"
    # 修正：Mihomo 通常是 .gz 格式且文件名带版本号
    CORE_NAME="mihomo-linux-amd64-compatible-${CORE_VER}.gz"
    CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/${CORE_NAME}"
    # 备选链接 (部分版本可能不带版本号前缀)
    BACKUP_URL="https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/mihomo-linux-amd64-compatible.gz"
    
    echo "📥 正在下载 Mihomo 内核..."
    if curl -fsSL -o core.gz "$CORE_URL" || curl -fsSL -o core.gz "$BACKUP_URL" || curl -fsSL -o core.gz "https://gh-proxy.com/${CORE_URL}"; then
        # 验证并解压
        if file core.gz | grep -q "gzip compressed data"; then
            gunzip -c core.gz > mihomo
            chmod +x mihomo
            rm -f core.gz
            echo "✅ Mihomo 内核预置成功"
        else
            echo "❌ 错误: 下载的文件不是有效的 gzip 压缩包"
            exit 1
        fi
    else
        echo "❌ 错误: 无法下载内核，请检查 CORE_VER 或网络连接"
        exit 1
    fi
)

# 3. 修改固件默认参数
# 修改主机名
sed -i "s|hostname='.*'|hostname='OpenWrt-25.12'|g" package/base-files/files/bin/config_generate
# 修改时区
sed -i "s|timezone='.*'|timezone='CST-8'|g" package/base-files/files/bin/config_generate
sed -i "/timezone='.*'/a\set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate
# 修改 LAN IP
sed -i "s|192.168.1.1|192.168.80.80|g" package/base-files/files/bin/config_generate

echo "✅ DIY 脚本执行完毕"
