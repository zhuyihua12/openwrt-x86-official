#!/bin/bash
set -e

echo "OpenWrt DIY Pre-processing Script..."

# ========================================
# Fix Rust Build Issue (Python 3.13 Compatibility)
# ========================================
# Problem: OpenWrt v25.12.1 uses Python 3.13 which no longer provides setuptools
# Reference: https://github.com/openwrt/packages/pull/27810

echo "Fixing Rust/Python package setuptools dependencies..."

# Fix rust package
if [ -f "feeds/packages/lang/rust/Makefile" ]; then
    echo "  -> Fixing rust package..."
    if ! grep -q "python-setuptools/host" feeds/packages/lang/rust/Makefile 2>/dev/null; then
        cat > /tmp/rust_patch.txt << 'EOF'
HOST_BUILD_DEPENDS:=python3/host python-setuptools/host
EOF
        sed -i '/^include.*rules.mk/r /tmp/rust_patch.txt' feeds/packages/lang/rust/Makefile
    fi
fi

# Fix cargo-c package
if [ -f "feeds/packages/devel/cargo-c/Makefile" ]; then
    echo "  -> Fixing cargo-c package..."
    if ! grep -q "python-setuptools/host" feeds/packages/devel/cargo-c/Makefile 2>/dev/null; then
        cat > /tmp/cargo_patch.txt << 'EOF'
HOST_BUILD_DEPENDS:=python3/host python-setuptools/host
EOF
        sed -i '/^include.*rules.mk/r /tmp/cargo_patch.txt' feeds/packages/devel/cargo-c/Makefile
    fi
fi

# Fix python-setuptools-rust package
if [ -f "feeds/packages/lang/python/python-setuptools-rust/Makefile" ]; then
    echo "  -> Fixing python-setuptools-rust package..."
    if ! grep -q "python-setuptools/host" feeds/packages/lang/python/python-setuptools-rust/Makefile 2>/dev/null; then
        sed -i 's/HOST_BUILD_DEPENDS:=/HOST_BUILD_DEPENDS:=python-setuptools\/host /' feeds/packages/lang/python/python-setuptools-rust/Makefile
    fi
fi

echo "Setuptools dependency fix completed"

# ========================================
# Pre-install OpenClash Source
# ========================================
mkdir -p package/lean
if [ ! -d "package/lean/openclash" ]; then
    echo "Cloning OpenClash from GitHub..."
    git clone --depth 1 https://github.com/vernesong/OpenClash.git package/lean/openclash
fi

# ========================================
# Pre-install Meta Core (Mihomo)
# ========================================
(
    CORE_DIR="files/etc/openclash/core"
    mkdir -p "$CORE_DIR"
    cd "$CORE_DIR"

    CORE_VER="v1.19.0"
    CORE_NAME="mihomo-linux-amd64-compatible-${CORE_VER}.gz"
    CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/${CORE_NAME}"

    echo "Downloading core: ${CORE_NAME}"

    if curl -fsSL --retry 3 -o core.gz "$CORE_URL" || \
       curl -fsSL --retry 3 -o core.gz "https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/mihomo-linux-amd64-compatible.gz"; then
        if file core.gz | grep -q "gzip compressed data"; then
            gunzip -c core.gz > mihomo
            chmod +x mihomo
            rm -f core.gz
            echo "Mihomo core deployed successfully"
        else
            echo "Error: Downloaded file is not a valid gzip archive"
            exit 1
        fi
    else
        echo "Error: Cannot download core, please verify version $CORE_VER"
        exit 1
    fi
)

# ========================================
# Modify Default System Parameters
# ========================================
sed -i "s|hostname='.*'|hostname='OpenWrt-25.12'|g" package/base-files/files/bin/config_generate
sed -i "s|192.168.1.1|192.168.80.80|g" package/base-files/files/bin/config_generate
sed -i "s|timezone='.*'|timezone='CST-8'|g" package/base-files/files/bin/config_generate
sed -i "/timezone='.*'/a\set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

echo "DIY pre-processing completed"
