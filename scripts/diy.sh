#!/bin/bash
set -e

echo "OpenWrt DIY Pre-processing Script..."

# ========================================
# Fix Rust Build Issue (Python 3.13 Compatibility + CI Environment)
# ========================================
# Problem 1: OpenWrt v25.12.1 uses Python 3.13 which no longer provides setuptools
# Problem 2: Rust build fails on CI with 'llvm.download-ci-llvm' error
# Reference: https://github.com/openwrt/packages/pull/27810

echo "Fixing Rust/Python package dependencies..."

# Fix rust package - add setuptools dependency and fix CI LLVM config
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

# Fix Rust CI LLVM configuration issue - set to false instead of if-unchanged
echo "  -> Fixing Rust CI LLVM configuration..."
if [ -f "feeds/packages/lang/rust/rust-host-build.mk" ]; then
    # Modify the rust build configuration to handle CI environment
    sed -i 's/--set llvm.download-ci-llvm=true/--set llvm.download-ci-llvm=false/g' feeds/packages/lang/rust/rust-host-build.mk 2>/dev/null || true
fi

# Alternative: Patch the config.toml generation in rust Makefile
if [ -f "feeds/packages/lang/rust/Makefile" ]; then
    # Replace download-ci-llvm=true with false in the Makefile
    sed -i 's/download-ci-llvm=true/download-ci-llvm=false/g' feeds/packages/lang/rust/Makefile
    # Also replace if-unchanged with false if it was set
    sed -i 's/download-ci-llvm=if-unchanged/download-ci-llvm=false/g' feeds/packages/lang/rust/Makefile
fi

echo "Rust dependency fix completed"

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

    CORE_VER="v1.19.34"
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
        echo "Error: Cannot download core, please verify version $CORE_VER is correct"
        exit 1
    fi
)

# ========================================
# Pre-install vlmcsd + LuCI app (removed from OpenWrt 25.12 feeds, take from ImmortalWrt)
# ========================================
mkdir -p package/custom
if [ ! -d "package/custom/vlmcsd" ]; then
    echo "Fetching vlmcsd + luci-app-vlmcsd from ImmortalWrt..."
    git clone --depth 1 --filter=blob:none --sparse https://github.com/immortalwrt/packages.git /tmp/im-pkgs
    (cd /tmp/im-pkgs && git sparse-checkout set net/vlmcsd)
    cp -r /tmp/im-pkgs/net/vlmcsd package/custom/vlmcsd

    git clone --depth 1 --filter=blob:none --sparse https://github.com/immortalwrt/luci.git /tmp/im-luci
    (cd /tmp/im-luci && git sparse-checkout set applications/luci-app-vlmcsd)
    cp -r /tmp/im-luci/applications/luci-app-vlmcsd package/custom/luci-app-vlmcsd
    # ImmortalWrt 树内相对路径改为 feed 绝对路径
    sed -i 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|' package/custom/luci-app-vlmcsd/Makefile
    rm -rf /tmp/im-pkgs /tmp/im-luci
fi

# ========================================
# Pre-install mosdns (sbwml feed, 官方 feed 无此包) + golang 工具链升级
# ========================================
if [ ! -d "package/custom/mosdns-feed" ]; then
    echo "Cloning mosdns (sbwml v5)..."
    git clone --depth 1 -b v5 https://github.com/sbwml/luci-app-mosdns.git package/custom/mosdns-feed
    # mosdns v5.3.x 需要新版 golang 工具链，替换官方 lang/golang
    if [ -d "feeds/packages/lang/golang" ]; then
        echo "Replacing lang/golang with sbwml 26.x fork..."
        rm -rf feeds/packages/lang/golang
        git clone --depth 1 -b 26.x https://github.com/sbwml/packages_lang_golang.git feeds/packages/lang/golang
    fi
fi

# ========================================
# Modify Default System Parameters
# ========================================
sed -i "s|hostname='.*'|hostname='OpenWrt'|g" package/base-files/files/bin/config_generate
sed -i "s|timezone='.*'|timezone='CST-8'|g" package/base-files/files/bin/config_generate
sed -i "/timezone='.*'/a\set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

echo "DIY pre-processing completed"
