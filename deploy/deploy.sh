#!/usr/bin/env bash
# =============================================================================
# openwrt-x86-official  Ubuntu 服务器一键部署
#   自动完成：系统更新(apt 源自动探活/换国内镜像) → Docker 容器环境 →
#             项目文件就位 → 防火墙收紧(仅放行 22 等必要端口) → 构建编译镜像
# 可选 --build 直接开始编译固件。
#
# 用法（在项目根目录或解压目录内执行）:
#   sudo bash deploy/deploy.sh              # 部署环境
#   sudo bash deploy/deploy.sh --build      # 部署并立即编译
# 常用参数: --skip-firewall --skip-update --skip-docker --work-dir DIR
#           --offline-tar A.tar.gz(离线导入基础镜像) --no-build-image
# 详见 deploy/DEPLOY.md
# =============================================================================
set -euo pipefail

# ---------- 参数 ----------
WORK_DIR=${WORK_DIR:-/srv/openwrt-build}
APT_MIRROR=auto          # auto|cn|official
BUILD=0; SKIP_FIREWALL=0; SKIP_UPDATE=0; SKIP_DOCKER=0; BUILD_IMAGE=1
OFFLINE_TAR=""
SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_SRC=$(dirname "$SELF_DIR")

while [ $# -gt 0 ]; do
  case "$1" in
    --build) BUILD=1 ;;
    --skip-firewall) SKIP_FIREWALL=1 ;;
    --skip-update) SKIP_UPDATE=1 ;;
    --skip-docker) SKIP_DOCKER=1 ;;
    --no-build-image) BUILD_IMAGE=0 ;;
    --work-dir) WORK_DIR=$2; shift ;;
    --apt-mirror) APT_MIRROR=$2; shift ;;
    --offline-tar) OFFLINE_TAR=$2; shift ;;
    -h|--help) grep '^# ' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1（--help 看用法）"; exit 1 ;;
  esac
  shift
done

log()  { echo -e "\e[1;36m[部署]\e[0m $*"; }
warn() { echo -e "\e[1;33m[警告]\e[0m $*"; }
die()  { echo -e "\e[1;31m[失败]\e[0m $*"; exit 1; }

[ "$(id -u)" = 0 ] || die "请用 root / sudo 运行"
grep -qi ubuntu /etc/os-release || die "本脚本仅支持 Ubuntu"
command -v git >/dev/null || { apt-get update -qq; apt-get install -y -qq git; }

# ---------- 0. 网络探活 ----------
probe() { curl -fsS -m 6 -o /dev/null "$1" 2>/dev/null; }
OFFICIAL_OK=1; probe http://archive.ubuntu.com/ubuntu/ || OFFICIAL_OK=0
GH_OK=1;       probe https://github.com/                || GH_OK=0
log "网络探测: 官方 apt 源 $( [ $OFFICIAL_OK = 1 ] && echo 可达 || echo 不可达 ), GitHub $( [ $GH_OK = 1 ] && echo 可达 || echo 不可达 )"

# ---------- 1. apt 源自适应 + 系统更新 ----------
if [ "$SKIP_UPDATE" = 0 ]; then
  log "1/6 系统更新"
  USE_CN=0
  if [ "$APT_MIRROR" = cn ]; then USE_CN=1
  elif [ "$APT_MIRROR" = auto ] && [ "$OFFICIAL_OK" = 0 ]; then USE_CN=1; log "官方源不可达 → 切换国内镜像(阿里云)"
  fi
  if [ "$USE_CN" = 1 ]; then
    STAMP=$(date +%s)
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources; do
      [ -f "$f" ] || continue
      cp "$f" "${f}.bak.${STAMP}"
      sed -ri 's#https?://(cn\.)?archive\.ubuntu\.com#http://mirrors.aliyun.com#g; s#https?://security\.ubuntu\.com#http://mirrors.aliyun.com#g' "$f"
    done
  fi
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold full-upgrade
else
  log "1/6 跳过系统更新(--skip-update)"
fi

# ---------- 2. 基础工具 + Docker ----------
if [ "$SKIP_DOCKER" = 0 ]; then
  log "2/6 安装 docker.io 与基础工具"
  apt-get install -y docker.io git curl ca-certificates rsync ufw
  systemctl enable --now docker
else
  log "2/6 跳过 Docker 安装(--skip-docker)"
fi

# ---------- 3. 防火墙收紧：默认拒入站，仅放行 SSH(含22) ----------
if [ "$SKIP_FIREWALL" = 0 ]; then
  log "3/6 防火墙：默认拒绝入站，仅放行 SSH 端口"
  SSH_PORTS=$(ss -tlnp 2>/dev/null | awk '/sshd/ {gsub(/.*:/,"",$4); print $4}' | sort -u | tr '\n' ' ')
  [ -n "$SSH_PORTS" ] || SSH_PORTS="22 "
  warn "将放行的入站端口:${SSH_PORTS}（务必确认与你当前连接一致，误配会断 SSH）"
  for p in $SSH_PORTS; do
    [ "$p" = "*" ] && continue
    ufw allow "$p"/tcp comment 'deploy-ssh' >/dev/null
  done
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null
  ufw --force enable
  ufw status verbose
else
  log "3/6 跳过防火墙(--skip-firewall)"
fi

# ---------- 4. 项目文件就位 ----------
log "4/6 项目文件 → $WORK_DIR/project"
mkdir -p "$WORK_DIR/project" "$WORK_DIR/openwrt-src" "$WORK_DIR/dl"
if [ -f "$PROJECT_SRC/configs/openwrt.version" ] && [ -f "$PROJECT_SRC/deploy/deploy.sh" ]; then
  # 从已下载/克隆的项目目录执行：直接同步过来（离线场景友好）
  rsync -a --delete --exclude .git "$PROJECT_SRC/" "$WORK_DIR/project/"
  log "来源: 本机项目目录 $PROJECT_SRC"
elif [ "$GH_OK" = 1 ]; then
  git clone --depth 1 https://github.com/zhuyihua12/openwrt-x86-official.git "$WORK_DIR/project-tmp"
  rsync -a "$WORK_DIR/project-tmp/" "$WORK_DIR/project/" && rm -rf "$WORK_DIR/project-tmp"
  log "来源: GitHub 克隆"
else
  die "当前目录不是项目文件，GitHub 也不可达——请参考 DEPLOY.md 用 scp/压缩包把项目拷到服务器后重跑"
fi

# ---------- 5. 构建编译镜像 ----------
if [ "$SKIP_DOCKER" = 0 ] && [ "$BUILD_IMAGE" = 1 ]; then
  log "5/6 构建编译容器镜像 openwrt-x86-builder:22.04"
  if [ -n "$OFFLINE_TAR" ] && [ -f "$OFFLINE_TAR" ]; then
    docker load -i "$OFFLINE_TAR"
    log "已从离线包导入镜像"
  fi
  if ! docker image inspect openwrt-x86-builder:22.04 >/dev/null 2>&1; then
    if ! probe https://registry-1.docker.io/v2/ ; then
      warn "Docker Hub 不可达 → 写入国内 registry mirror 并重试"
      mkdir -p /etc/docker
      cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run",
    "https://hub.rat.dev"
  ]
}
EOF
      systemctl restart docker
    fi
    docker build -t openwrt-x86-builder:22.04 "$WORK_DIR/project/deploy"
  else
    log "镜像已存在，跳过构建"
  fi
else
  log "5/6 跳过镜像构建"
fi

# ---------- 6. 可选：立即编译 ----------
if [ "$BUILD" = 1 ]; then
  log "6/6 开始容器内编译（2-4h；产物在 $WORK_DIR/openwrt-src/bin/targets/x86/64/）"
  chown -R 1000:1000 "$WORK_DIR/openwrt-src" "$WORK_DIR/dl"   # 容器内 builder=1000
  docker run --rm \
    -v "$WORK_DIR/project:/project:ro" \
    -v "$WORK_DIR/openwrt-src:/build/openwrt-src" \
    -v "$WORK_DIR/dl:/build/dl" \
    -e SRC=/build/openwrt-src \
    openwrt-x86-builder:22.04 \
    bash /project/deploy/build-firmware.sh
else
  log "6/6 未启动编译。随时执行: sudo bash $(realpath "$0") --build"
fi

log "✅ 部署完成"
echo "  工作目录: $WORK_DIR"
echo "  编译产物: $WORK_DIR/openwrt-src/bin/targets/x86/64/ (squashfs .img.gz + .vmdk)"
echo "  防火墙  : ufw status verbose"
