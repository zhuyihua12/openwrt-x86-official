#!/usr/bin/env bash
# 容器内固件编译脚本：复刻 .github/workflows/build.yml 全流程（squashfs-only 规矩含在内）
# 由 deploy.sh 通过 docker run 调起；环境变量可覆盖：SRC / FEEDS_MODE
set -euo pipefail

PROJECT=${PROJECT:-/project}
SRC=${SRC:-/build/openwrt-src}
OPENWRT_REPO=${OPENWRT_REPO:-https://github.com/openwrt/openwrt.git}

log() { echo "===== $(date '+%F %T') $* ====="; }

log "本次编译基于: $(tr -d '[:space:]' < "$PROJECT/configs/openwrt.version")"

# ---------- 源码 ----------
if [ ! -d "$SRC/.git" ]; then
  log "获取 OpenWrt 源码"
  git clone "$OPENWRT_REPO" -b "$(tr -d '[:space:]' < "$PROJECT/configs/openwrt.version")" "$SRC"
fi
cd "$SRC"

# ---------- feeds：官方源 git.openwrt.org 在防火墙内常不可达，改写为 GitHub（OpenWrt 论坛官方手法） ----------
if [ ! -f feeds.conf ]; then
  sed -e 's,git\.openwrt\.org/feed,github.com/openwrt,g' \
      -e 's,git\.openwrt\.org/project,github.com/openwrt,g' \
      feeds.conf.default > feeds.conf
  log "feeds.conf 已改写为 GitHub 源："
  cat feeds.conf
fi
log "更新 Feeds"
./scripts/feeds update -a
./scripts/feeds install -a

# ---------- 覆盖层 + 断言（与 CI Step「执行 DIY 脚本」一致） ----------
mkdir -p files
cp -r "$PROJECT/files/." ./files/
for f in files/etc/uci-defaults/zz-ipv6-mosdns files/etc/firewall.user files/etc/openclash/custom/openclash_custom_firewall_rules.sh; do
  [ -f "$f" ] || { echo "❌ 覆盖层缺文件: $f"; exit 1; }
done
grep -q "remote_dns='127.0.0.1:7874'" files/etc/uci-defaults/zz-ipv6-mosdns || { echo "❌ 缺 mosdns remote_dns 分流键"; exit 1; }
grep -q "dhcp.lan.ignore='1'" files/etc/uci-defaults/zz-ipv6-mosdns || { echo "❌ 缺 LAN DHCP 忽略键"; exit 1; }
cp -f "$PROJECT/scripts/diy.sh" .
bash diy.sh
echo "✅ 覆盖层完整"

# ---------- 配置生成（与 CI Step「生成配置」一致） ----------
log "生成 .config"
echo "CONFIG_TARGET_x86=y" > .config
echo "CONFIG_TARGET_x86_64=y" >> .config
echo "CONFIG_TARGET_x86_64_DEVICE_generic=y" >> .config
make defconfig
sed -i 's/^CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/' .config
grep -v -E '^(CONFIG_TARGET_|CONFIG_GRUB_|CONFIG_VMDK_|#|$)' "$PROJECT/configs/x86_64.config" >> .config
sed -i 's/^CONFIG_PACKAGE_libwebsockets-openssl=y/# CONFIG_PACKAGE_libwebsockets-openssl is not set/' .config
sed -i 's/^CONFIG_PACKAGE_libwebsockets-mbedtls=y/# CONFIG_PACKAGE_libwebsockets-mbedtls is not set/' .config
if grep -q '^CONFIG_TARGET_ROOTFS_PARTSIZE=' .config; then
  sed -i 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/' .config
else
  echo "CONFIG_TARGET_ROOTFS_PARTSIZE=512" >> .config
fi
# 项目规矩(2026-11-23): 只编译 squashfs 版
if grep -q '^CONFIG_TARGET_ROOTFS_EXT4FS=y' .config; then
  sed -i 's/^CONFIG_TARGET_ROOTFS_EXT4FS=y/# CONFIG_TARGET_ROOTFS_EXT4FS is not set/' .config
else
  echo "# CONFIG_TARGET_ROOTFS_EXT4FS is not set" >> .config
fi
grep -q '^CONFIG_TARGET_ROOTFS_SQUASHFS=y' .config || echo "CONFIG_TARGET_ROOTFS_SQUASHFS=y" >> .config
for feed in CONFIG_FEED_packages CONFIG_FEED_luci CONFIG_FEED_routing CONFIG_FEED_telephony; do
  grep -q "^${feed}=y" .config || echo "${feed}=y" >> .config
done
make defconfig

log "校验关键包"
grep -E '^CONFIG_PACKAGE_[^=]+=y$' "$PROJECT/configs/x86_64.config" | sed -E 's/^CONFIG_PACKAGE_//; s/=y$//' > /tmp/expected.txt
echo luci >> /tmp/expected.txt; echo luci-base >> /tmp/expected.txt
sort -u /tmp/expected.txt -o /tmp/expected.txt
MISSING=0
while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue
  if grep -q "^CONFIG_PACKAGE_${pkg}=y" .config; then
    echo "✅ $pkg"
  else
    echo "❌ $pkg 缺失 — 强制写入"
    echo "CONFIG_PACKAGE_${pkg}=y" >> .config
    MISSING=$((MISSING+1))
  fi
done < /tmp/expected.txt
[ "$MISSING" -gt 0 ] && make defconfig

grep '^CONFIG_TARGET_ROOTFS_PARTSIZE=' .config || { echo "❌ PARTSIZE 丢失"; exit 1; }
grep '^CONFIG_LUCI_LANG_zh_Hans=y' .config || { echo "❌ 中文未启用"; exit 1; }
grep '^CONFIG_TARGET_ROOTFS_SQUASHFS=y' .config || { echo "❌ squashfs 未启用"; exit 1; }
if grep -q '^CONFIG_TARGET_ROOTFS_EXT4FS=y' .config; then echo "❌ ext4 未关闭"; exit 1; fi
echo "✅ 配置校验通过（仅 squashfs 规矩守住）"

# ---------- 编译 ----------
log "预下载依赖（dl 缓存在容器外挂载，可断点续跑）"
make download -j"$(nproc)" || make download -j1 V=s
log "核心编译（时长约 2-4h，取决于机器）"
make -j"$(nproc)" || make -j1 V=s

# ---------- 产物断言（与 CI 一致） ----------
BIN=bin/targets/x86/64
log "产物断言"
ls "$BIN"/openwrt-x86-64-generic-squashfs-combined-efi.img.gz >/dev/null || { echo "❌ squashfs 镜像不存在"; exit 1; }
if ls "$BIN"/openwrt-x86-64-generic-ext4-combined* >/dev/null 2>&1; then echo "❌ 竟然产出 ext4 镜像"; exit 1; fi
for m in "$BIN"/*.manifest; do
  [ -f "$m" ] || continue
  for need in luci-i18n-base-zh-cn mosdns odhcp6c odhcpd; do
    grep -q "^${need} " "$m" || grep -q "${need} -" "$m" || { echo "❌ $(basename "$m") 缺 $need"; exit 1; }
  done
done
log "生成 VMDK"
IMG="$BIN/openwrt-x86-64-generic-squashfs-combined-efi.img"
[ -f "$IMG" ] || gunzip -k "${IMG}.gz"
qemu-img convert -O vmdk -o subformat=monolithicSparse "$IMG" "${IMG%.img}.vmdk"

log "🎉 编译完成，产物："
ls -lh "$BIN"/*.img.gz "$BIN"/*.vmdk
