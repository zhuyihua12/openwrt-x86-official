#!/bin/bash
set -e

echo "🛠️ 开始执行 DIY 预处理脚本..."

# 1. 预置 OpenClash 源码
mkdir -p package/lean
if [ ! -d "package/lean/openclash" ]; then
    echo "📥 正在克隆 OpenClash..."
    git clone --depth 1 https://github.com/vernesong/OpenClash.git package/lean/openclash
fi

# 2. 预置 Meta 内核 (使用子 shell 隔离路径切换)
(
    CORE_DIR="files/etc/openclash/core"
    mkdir -p "$CORE_DIR"
    cd "$CORE_DIR"
    
    CORE_VER="v1.19.0"
    CORE_NAME="mihomo-linux-amd64-compatible.tar.gz"
    CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/${CORE_NAME}"
    
    echo "📥 正在下载 Mihomo 内核..."
    # 使用 -fsSL 确保失败时不保存错误网页，并增加重试
    if ! curl -fsSL -o core.tar.gz "$CORE_URL"; then
        echo "⚠️ 主源失败，尝试使用 GH-Proxy..."
        curl -fsSL -o core.tar.gz "https://gh-proxy.com/${CORE_URL}"
    fi

    # 关键修复：验证文件是否为有效的 gzip 压缩包
    if file core.tar.gz | grep -q "gzip compressed data"; then
        tar -xzf core.tar.gz mihomo-linux-amd64-compatible
        mv mihomo-linux-amd64-compatible mihomo
        chmod +x mihomo
        rm -f core.tar.gz
        echo "✅ Mihomo 内核预置成功"
    else
        echo "❌ 错误: 下载的文件不是有效的内核压缩包 (可能是 404 页面)"
        echo "文件内容预览: $(head -n 1 core.tar.gz)"
        exit 1
    fi
)

# 3. 修改固件默认参数
# 修改主机名
sed -i "s|hostname='.*'|hostname='OpenWrt-25.12'|g" package/base-files/files/bin/config_generate
# 修改时区 (设置为上海)
sed -i "s|timezone='.*'|timezone='CST-8'|g" package/base-files/files/bin/config_generate
sed -i "/timezone='.*'/a\set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate
# 修改 LAN 默认 IP
sed -i "s|192.168.1.1|192.168.80.80|g" package/base-files/files/bin/config_generate

echo "✅ DIY 脚本执行完毕"
