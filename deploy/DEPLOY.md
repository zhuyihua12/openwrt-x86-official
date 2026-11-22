# Ubuntu 服务器一键部署指南（防火墙内环境友好）

把这台 Ubuntu 服务器变成 **openwrt-x86-official 固件编译机**：一条命令完成系统更新、
Docker 容器、项目文件就位、防火墙收紧，然后容器内产出与 GitHub CI 完全同规格的
**squashfs 固件**（本项目规矩：只编译 squashfs 版）。

```
GitHub 项目文件 ──→ Ubuntu 服务器 ──→ deploy.sh 一键部署
                                        ├─ apt 源探活（官方不可达自动换阿里云镜像）
                                        ├─ 系统更新
                                        ├─ Docker + 编译容器镜像
                                        ├─ 防火墙：默认拒入站，只放行 SSH(22)
                                        └─ --build 容器内编译 → squashfs .img.gz / .vmdk
```

---

## 0. 前置要求

| 项 | 要求 |
|---|---|
| 系统 | Ubuntu 22.04 / 24.04（root 或 sudo 权限） |
| 磁盘 | ≥ 60 GB 空闲（源码+编译中间物约 40GB） |
| 内存 | ≥ 8 GB（`make -j$(nproc)` 编译很吃内存） |
| 网络 | 见下方"网络三档"，**官方源不通也能部** |

**网络三档**（脚本自动探测，无需手工配置）：

| 目标 | 可达 | 不可达时的降级方案 |
|---|---|---|
| 官方 apt 源 | 正常用 | 自动切阿里云镜像 |
| GitHub | 项目/OpenWrt 源码/feeds 全走 GitHub | 项目文件走 scp/压缩包离线拷入；源码走"离线源码包"（见 FAQ 6.3） |
| Docker Hub | 正常 pull | 自动写入国内 registry mirror；仍不行走 `--offline-tar` 离线导入 |

> OpenWrt 官方 feeds 源 `git.openwrt.org` 在防火墙上通常不通，容器内脚本已自动改写为
> GitHub 上的官方仓库（OpenWrt 论坛标准做法），不需要额外处理。

---

## 1. 第一步：把项目文件弄到服务器（三选一）

### 方式 A：服务器能直连 GitHub（最简单）

```bash
git clone https://github.com/zhuyihua12/openwrt-x86-official.git
cd openwrt-x86-official
```

### 方式 B：服务器不通外网 → 在你电脑上下载后 scp 上去

在你自己的电脑（能访问 GitHub 的任意机器）：

```bash
# 下载最新 main 分支压缩包（或到仓库页面 Code → Download ZIP）
curl -L -o openwrt-x86-official-main.zip \
  https://github.com/zhuyihua12/openwrt-x86-official/archive/refs/heads/main.zip

# 传到服务器并解压
scp openwrt-x86-official-main.zip user@服务器IP:/tmp/
ssh user@服务器IP
cd /tmp && unzip openwrt-x86-official-main.zip && mv openwrt-x86-official-main ~/openwrt-x86-official
cd ~/openwrt-x86-official
```

### 方式 C：跳板机/内网分发

任何能放文件的通道都行，只要保证目录里有 `configs/openwrt.version`、`files/`、`deploy/`
这些内容（deploy.sh 会自动识别"我在项目目录里"）。

---

## 2. 第二步：一键部署

```bash
cd openwrt-x86-official          # 项目根目录
sudo bash deploy/deploy.sh       # 只部署环境
# 或部署完直接开编：
sudo bash deploy/deploy.sh --build
```

脚本幂等，可反复重跑（已完成的步骤自动跳过）。常用参数：

| 参数 | 作用 |
|---|---|
| `--build` | 部署后立即容器内编译 |
| `--skip-firewall` | 不动防火墙（已有自建防火墙时用） |
| `--skip-update` | 跳过系统更新 |
| `--skip-docker` | 不装 Docker、不建镜像 |
| `--apt-mirror cn\|official\|auto` | 强制用国内/官方源（默认 auto 探活） |
| `--work-dir DIR` | 工作目录（默认 `/srv/openwrt-build`） |
| `--offline-tar X.tar` | 离线导入编译镜像（`docker save` 产物，见 FAQ 6.2） |

---

## 3. 脚本到底做了什么（6 步）

1. **网络探活 + apt 源自适应**：`archive.ubuntu.com` 不可达 → 备份原源后切阿里云镜像
   （`/etc/apt/sources.list` 与 24.04 的 `ubuntu.sources` 两种格式都处理）
2. **系统自身更新**：`apt full-upgrade`，非交互模式不弹菜单
3. **防火墙收紧**：
   - 自动探测 sshd 实际监听端口（默认含 22），**先放行再启用**，不会把自己锁在门外
   - `default deny incoming` / `default allow outgoing`（编译需要出站拉代码）
   - 入站最终只有：SSH 端口。编译机不需要任何其它监听服务
4. **项目文件就位**：脚本在项目目录内运行 → rsync 到 `/srv/openwrt-build/project`；
   不在项目内且 GitHub 可达 → 自动 clone；两者都不行 → 明确报错并指向本文档
5. **构建编译镜像**：基于 `deploy/Dockerfile`（Ubuntu 22.04 + CI 同款工具链 +
   非 root `builder` 用户——OpenWrt 禁止 root 编译）；Docker Hub 不通自动配国内
   registry mirror 重试
6. **可选编译**：`docker run` 挂载 `project(只读)/源码/dl 缓存` 三个卷跑
   `deploy/build-firmware.sh`——**与 GitHub CI 步骤一一对应**：
   覆盖层+断言 → 配置生成（含"只编译 squashfs"三重断言）→ `make download` →
   `make -j` → 产物断言（无 ext4、manifest 含中文包/mosdns/odhcpd）→ 生成 VMDK

---

## 4. 第三步：编译与产物

```bash
# 没加 --build 的话，随时：
sudo bash deploy/deploy.sh --build
```

- 首次约 **2–4 小时**（看 CPU）；中断重跑 `--build` 即**断点续编**（源码和 dl 下载
  缓存都在宿主机卷里，不丢进度）
- 产物（与 GitHub Release 同规格）：

```
/srv/openwrt-build/openwrt-src/bin/targets/x86/64/
  openwrt-x86-64-generic-squashfs-combined-efi.img.gz   ← 写 U 盘/SSD / 虚拟机导入
  openwrt-x86-64-generic-squashfs-combined-efi.vmdk     ← VMware/ESXi 直挂
```

- 快速自检（与 CI 断言同款）：

```bash
BIN=/srv/openwrt-build/openwrt-src/bin/targets/x86/64
ls $BIN/*squashfs-combined-efi.img.gz        # 必须存在
ls $BIN/*ext4-combined* 2>/dev/null          # 必须为空（squashfs 规矩）
grep -E '^(mosdns|odhcpd|luci-i18n-base-zh-cn) ' $BIN/*.manifest   # 关键包在列
```

写盘烧录：`gunzip -c xxx.img.gz | sudo dd of=/dev/sdX bs=4M status=progress`
（或 balenaEtcher），细节与 README 主文档一致。

---

## 5. 防火墙速查

```bash
sudo ufw status verbose     # 查看
sudo ufw allow 22/tcp       # 追加端口（一般不需要）
```

**万一被锁在门外**（换端口/误操作）：从云厂商 VNC / 物理控制台登录执行
`sudo ufw disable`，核对规则后再 `sudo ufw enable`。脚本永远"先 allow 后 enable"，
正常流程不会发生。

---

## 6. FAQ

**6.1 `docker build` 卡在 pull ubuntu:22.04**
脚本已自动写 mirror（daocloud/1ms/hub.rat.dev）。若全部失效走 6.2。

**6.2 Docker 完全不通（最严格防火墙）**
在任何能访问 Docker Hub 的机器上：

```bash
docker pull ubuntu:22.04
docker build -t openwrt-x86-builder:22.04 <项目目录>/deploy
docker save openwrt-x86-builder:22.04 | gzip > builder.tar.gz
# scp builder.tar.gz 到服务器，然后：
sudo bash deploy/deploy.sh --offline-tar builder.tar.gz
```

**6.3 GitHub 也不通（连 OpenWrt 源码都拉不动）**
在有网机器上准备两个包，scp 到服务器对应路径：

```bash
# 1) OpenWrt 源码（版本号见 configs/openwrt.version，保持一致）
git clone --depth 1 -b <版本号> https://github.com/openwrt/openwrt.git openwrt-src
# 2) 依赖 tarball 缓存（有网机器上先 cd openwrt-src && make defconfig && make download）
tar czf dl.tar.gz openwrt-src/dl
# 服务器侧：
#   放到 /srv/openwrt-build/openwrt-src（保持 .git）
#   dl.tar.gz 解压到 /srv/openwrt-build/openwrt-src/
sudo bash deploy/deploy.sh --build   # 脚本检测到已有源码就不再 clone
```

feeds 同理可在有网机器 `./scripts/feeds update -a && tar czf feeds.tar.gz feeds/ package/feeds` 拷入，
或直接接受 `scripts/feeds` 在容器里走 GitHub（多数"防火墙内"只封 apt/官方源，GitHub 可达）。

**6.4 重复执行 deploy.sh 安全吗**
安全。apt 更新会跳过已完成项、镜像存在即跳过构建、防火墙规则 ufw 去重、rsync 增量。

**6.5 以后如何升级重编**
项目更新后把新的项目文件放回 `/srv/openwrt-build/project`（或方式 A 的
`git pull` 后重跑脚本），再 `--build`——源码目录 `git fetch && git checkout` 由容器脚本
处理版本切换，dl 缓存继续复用，越编越快。
