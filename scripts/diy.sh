#!/bin/bash
set -e

echo "🛠️ 开始执行云端 DIY 预处理脚本..."

# 注意: Rust LLVM 的 CI 检测问题已通过 workflow 中的 `unset CI` 解决
# 无需修改 Rust Makefile 中的 download-ci-llvm 配置

# 1. 预置 OpenClash 源码
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
    CORE_NAME="mihomo-linux-amd64-compatible-${CORE_VER}.gz"
    CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/${CORE_NAME}"

    echo "📥 正在下载内核: ${CORE_NAME}"

    if curl -fsSL --retry 3 -o core.gz "$CORE_URL" || \
       curl -fsSL --retry 3 -o core.gz "https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/mihomo-linux-amd64-compatible.gz"; then
        if file core.gz | grep -q "gzip compressed data"; then
            gunzip -c core.gz > mihomo
            chmod +x mihomo
            rm -f core.gz
            echo "✅ Mihomo 内核部署成功"
        else
            echo "❌ 错误: 下载的文件不是有效的内核压缩包"
            exit 1
        fi
    else
        echo "❌ 错误: 无法下载内核，请确认版本号 $CORE_VER 是否正确"
        exit 1
    fi
)

# 3. 修改默认系统参数
sed -i "s|hostname='.*'|hostname='OpenWrt-25.12'|g" package/base-files/files/bin/config_generate
sed -i "s|192.168.1.1|192.168.80.80|g" package/base-files/files/bin/config_generate
sed -i "s|timezone='.*'|timezone='CST-8'|g" package/base-files/files/bin/config_generate
sed -i "/timezone='.*'/a\set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

echo "✅ 云端预处理完成"