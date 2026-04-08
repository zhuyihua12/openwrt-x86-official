#!/bin/bash
set -e

echo "馃洜锔?寮€濮嬫墽琛屼簯绔?DIY 棰勫鐞嗚剼鏈?.."

# ========================================
# 淇 Rust 缂栬瘧闂 (Python 3.13 鍏煎鎬?
# ========================================
# 闂鍘熷洜: OpenWrt v25.12.1 浣跨敤 Python 3.13锛屼笉鍐嶈嚜鍔ㄦ彁渚?setuptools
# 鍙傝€? https://github.com/openwrt/packages/pull/27810

echo "馃敡 淇 Rust/Python 鍖呯殑 setuptools 渚濊禆..."

# 淇 rust 鍖?if [ -f "feeds/packages/lang/rust/Makefile" ]; then
    echo "  鈫?淇 rust 鍖?.."
    # 鍦?include 瑙勫垯鍚庢坊鍔?HOST_BUILD_DEPENDS
    if ! grep -q "python-setuptools/host" feeds/packages/lang/rust/Makefile; then
        sed -i '/^include.*rules.mk/a\
HOST_BUILD_DEPENDS:=python3/host python-setuptools/host' feeds/packages/lang/rust/Makefile
    fi
fi

# 淇 cargo-c 鍖?if [ -f "feeds/packages/devel/cargo-c/Makefile" ]; then
    echo "  鈫?淇 cargo-c 鍖?.."
    if ! grep -q "python-setuptools/host" feeds/packages/devel/cargo-c/Makefile; then
        sed -i '/^include.*rules.mk/a\
HOST_BUILD_DEPENDS:=python3/host python-setuptools/host' feeds/packages/devel/cargo-c/Makefile
    fi
fi

# 淇 python-setuptools-rust 鍖?if [ -f "feeds/packages/lang/python/python-setuptools-rust/Makefile" ]; then
    echo "  鈫?淇 python-setuptools-rust 鍖?.."
    if ! grep -q "python-setuptools/host" feeds/packages/lang/python/python-setuptools-rust/Makefile; then
        sed -i 's/HOST_BUILD_DEPENDS:=/HOST_BUILD_DEPENDS:=python-setuptools\/host /' feeds/packages/lang/python/python-setuptools-rust/Makefile
    fi
fi

echo "鉁?setuptools 渚濊禆淇瀹屾垚"

# ========================================
# 棰勭疆 OpenClash 婧愮爜
# ========================================
mkdir -p package/lean
if [ ! -d "package/lean/openclash" ]; then
    echo "馃摜 姝ｅ湪浠?GitHub 鍏嬮殕 OpenClash..."
    git clone --depth 1 https://github.com/vernesong/OpenClash.git package/lean/openclash
fi

# ========================================
# 棰勭疆 Meta 鍐呮牳 (Mihomo)
# ========================================
(
    CORE_DIR="files/etc/openclash/core"
    mkdir -p "$CORE_DIR"
    cd "$CORE_DIR"

    CORE_VER="v1.19.0"
    CORE_NAME="mihomo-linux-amd64-compatible-${CORE_VER}.gz"
    CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/${CORE_NAME}"

    echo "馃摜 姝ｅ湪涓嬭浇鍐呮牳: ${CORE_NAME}"

    if curl -fsSL --retry 3 -o core.gz "$CORE_URL" || \
       curl -fsSL --retry 3 -o core.gz "https://github.com/MetaCubeX/mihomo/releases/download/${CORE_VER}/mihomo-linux-amd64-compatible.gz"; then
        if file core.gz | grep -q "gzip compressed data"; then
            gunzip -c core.gz > mihomo
            chmod +x mihomo
            rm -f core.gz
            echo "鉁?Mihomo 鍐呮牳閮ㄧ讲鎴愬姛"
        else
            echo "鉂?閿欒: 涓嬭浇鐨勬枃浠朵笉鏄湁鏁堢殑鍐呮牳鍘嬬缉鍖?
            exit 1
        fi
    else
        echo "鉂?閿欒: 鏃犳硶涓嬭浇鍐呮牳锛岃纭鐗堟湰鍙?$CORE_VER 鏄惁姝ｇ‘"
        exit 1
    fi
)

# ========================================
# 淇敼榛樿绯荤粺鍙傛暟
# ========================================
sed -i "s|hostname='.*'|hostname='OpenWrt-25.12'|g" package/base-files/files/bin/config_generate
sed -i "s|192.168.1.1|192.168.80.80|g" package/base-files/files/bin/config_generate
sed -i "s|timezone='.*'|timezone='CST-8'|g" package/base-files/files/bin/config_generate
sed -i "/timezone='.*'/a\set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

echo "鉁?浜戠棰勫鐞嗗畬鎴?
