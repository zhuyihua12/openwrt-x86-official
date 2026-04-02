#!/bin/bash
set -e

echo "🛠️ 开始执行云端 DIY 预处理脚本..."

# 1. 预置 OpenClash 源码
# 远程服务器带宽大，直接 clone 即可
mkdir -p package/lean
if [ ! -d "package/lean/openclash" ]; then
    echo "📥 正在从 GitHub 克隆 OpenClash..."
    git clone --depth 1 https://github.com/vernesong/OpenClash.git package/lean/openclash
fi

# 2. 预置 Meta 内核 (Mihomo)
(
    CORE_DIR="files/etc/openclash/core"
    mkdir -p "$CORE_DIR"
    cd "$CORE_DIR"
    
    CORE_VER="v1.19.0"
    # 修正：Meta 仓库目前的标准命名格式
    CORE_NAME="mihomo-linux-amd64-compatible-${CORE_VER}.gz"
    CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/${CORE_NAME}"
    
    echo "📥 GitHub Actions 正在直接抓取内核: ${CORE_NAME}"
    
    # 尝试直接下载，如果失败则尝试不带版本号的链接
    if curl -fsSL -o core.gz "$CORE_URL" || \
       curl -fsSL -o core.gz "https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/mihomo-linux-amd64-compatible.gz"; then
        
        # 校验文件有效性，防止下到 404 网页
        if file core.gz | grep -q "gzip compressed data"; then
            echo "✅ 内核下载成功，正在解压部署..."
            gunzip -c core.gz > mihomo
            chmod +x mihomo
            rm -f core.gz
        else
            echo "❌ 严重错误: 下载的文件不是有效的压缩包，请检查 MetaCubeX 仓库 Release 命名"
            exit 1
        fi
    else
        echo "❌ 严重错误: 无法连接到 GitHub Release 下载内核"
        exit 1
    fi
)

# 3. 基础参数修改
# 主机名与默认 IP (192.168.80.80)
sed -i "s|hostname='.*'|hostname='OpenWrt-25.12'|g" package/base-files/files/bin/config_generate
sed -i "s|192.168.1.1|192.168.80.80|g" package/base-files/files/bin/config_generate

# 时区设置为上海
sed -i "s|timezone='.*'|timezone='CST-8'|g" package/base-files/files/bin/config_generate
sed -i "/timezone='.*'/a\set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

echo "✅ 云端预处理完成"
