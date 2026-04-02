#!/bin/bash
set -e

echo "🛠️ 开始执行云端 DIY 预处理脚本..."

# 1. 修正 Rust LLVM 配置 (解决 CI 环境编译 Rust 插件失败的问题)
mkdir -p feeds/packages/lang/rust
cat > feeds/packages/lang/rust/config.toml << 'EOF'
[llvm]
download-ci-llvm = "if-unchanged"
EOF
echo "✅ Rust LLVM 配置已修正"

# 2. 预置 OpenClash 源码
mkdir -p package/lean
if [ ! -d "package/lean/openclash" ]; then
    echo "📥 正在从 GitHub 克隆 OpenClash..."
    git clone --depth 1 https://github.com/vernesong/OpenClash.git package/lean/openclash
fi

# 3. 预置 Meta 内核 (Mihomo)
(
    CORE_DIR="files/etc/openclash/core"
    mkdir -p "$CORE_DIR"
    cd "$CORE_DIR"
    
    CORE_VER="v1.19.0"
    # 修正：针对 MetaCubeX 仓库的正确链接格式
    CORE_NAME="mihomo-linux-amd64-compatible-${CORE_VER}.gz"
    CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/${CORE_NAME}"
    
    echo "📥 正在下载内核: ${CORE_NAME}"
    
    # 尝试直接下载，失败则尝试不带版本号的链接
    if curl -fsSL -o core.gz "$CORE_URL" || \
       curl -fsSL -o core.gz "https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/mihomo-linux-amd64-compatible.gz"; then
        
        # 校验文件类型，防止 404 错误
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

# 4. 修改默认系统参数
# 修改主机名与默认 IP
sed -i "s|hostname='.*'|hostname='OpenWrt-25.12'|g" package/base-files/files/bin/config_generate
sed -i "s|192.168.1.1|192.168.80.80|g" package/base-files/files/bin/config_generate

# 修改时区 (设置为上海)
sed -i "s|timezone='.*'|timezone='CST-8'|g" package/base-files/files/bin/config_generate
sed -i "/timezone='.*'/a\set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

echo "✅ 云端预处理完成"
