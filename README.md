<div align="center">

<img src="https://img.shields.io/badge/OpenWrt-v25.12.1-00B5E2?style=for-the-badge&logo=openwrt&logoColor=white" />
<img src="https://img.shields.io/badge/Platform-x86__64-4CAF50?style=for-the-badge&logo=linux&logoColor=white" />
<img src="https://img.shields.io/badge/Firewall-nftables%20FW4-FF6B35?style=for-the-badge" />
<img src="https://img.shields.io/badge/OpenClash-Meta%20内核-9C27B0?style=for-the-badge" />
<img src="https://img.shields.io/badge/IPv6-关闭-e74c3c?style=for-the-badge" />
<img src="https://img.shields.io/github/actions/workflow/status/zhuyihua12/openwrt-x86-official/build.yml?style=for-the-badge&label=Build" />

<br/><br/>

# 🛡️ OpenWrt x86-64 官方源码编译固件

**基于 OpenWrt Official v25.12.1 · 纯净源码编译 · 全中文面板 · 预装常用插件**

[📥 下载固件](#-固件下载) · [🚀 快速开始](#-安装指南) · [⚙️ 预装插件](#️-预装插件) · [❓ 常见问题](#-常见问题)

</div>

---

## ✨ 项目特点

| 特性 | 说明 |
|------|------|
| 🧬 **官方纯净源码** | 基于 OpenWrt Official 最新稳定版 v25.12.1，从源码编译 |
| 🇨🇳 **全中文面板** | 所有 LuCI 插件均包含中文语言包 |
| 🌐 **OpenClash** | 预装 Meta 内核（mihomo v1.19.0），支持 Rule-Based 分流 |
| 🔍 **Dnsmasq 完整版** | 替换默认版，支持更多 DNS 功能，已解决与 OpenClash 冲突 |
| 📺 **KMS 激活** | 预装 vlmcsd，自动激活 Windows / Office |
| 🔗 **ZeroTier** | 内网穿透，随时随地访问家庭网络 |
| 🚫 **IPv6 关闭** | 默认禁用 IPv6，适合纯 IPv4 环境 |
| 🎯 **编译精简** | 仅输出 IMG + VMDK 两种实用格式 |
| 🔄 **自动编译** | GitHub Actions 每日自动编译，也可手动触发 |

---

## 📥 固件下载

前往 **[Releases](https://github.com/zhuyihua12/openwrt-x86-official/releases)** 页面下载最新版本。

| 文件格式 | 适用场景 | 推荐度 |
|----------|----------|--------|
| `.img.gz` | 物理机写入 U 盘/SSD，导入 PVE/ESXi/Unraid/VirtualBox | ⭐⭐⭐⭐⭐ |
| `.vmdk` | VMware Workstation / ESXi 直接导入 | ⭐⭐⭐⭐ |

---

## 🚀 安装指南

### 物理机安装（U 盘 / SSD）

**Windows:** 推荐 [Rufus](https://rufus.ie/) 写入。

**Linux / macOS:**
```bash
gunzip openwrt-x86-64-combined.img.gz
sudo dd if=openwrt-x86-64-combined.img of=/dev/sdX bs=4M status=progress && sync
```
> ⚠️ 将 `/dev/sdX` 替换为实际设备，此操作会清空目标设备！

### 虚拟机安装（PVE）
```bash
gunzip openwrt-x86-64-combined.img.gz
qm importdisk 100 openwrt-x86-64-combined.img local-lvm
```
> 网卡建议选择 VirtIO（PVE）或 VMXNET3（ESXi）。

---

## 🔑 首次登录

| 项目 | 默认值 |
|------|--------|
| 管理地址 | `http://192.168.80.80` |
| 用户名 | `root` |
| 密码 | *(空)* |
| 主机名 | `OpenWrt-25.12` |
| 时区 | `Asia/Shanghai (CST-8)` |

> ⚠️ 默认 LAN IP 为 `192.168.80.80`，请确保电脑与路由器在同一网段。

---

## ⚙️ 预装插件

**🌐 网络代理**
- `luci-app-openclash` — OpenClash Meta 内核，Rule-Based 分流

**🔍 DNS 服务**
- `dnsmasq-full` — Dnsmasq 完整版，已解决与 OpenClash 冲突

**🔗 网络工具**
- `zerotier` + `luci-app-zerotier` — 内网穿透

**🖥️ 系统服务**
- `vlmcsd` + `luci-app-vlmcsd` — KMS 激活服务器
- `luci-app-ttyd` — Web 终端
- `openssh-sftp-server` — SFTP 文件传输
- `vsftpd` — FTP 服务

**🛠️ 实用工具**
- `curl` / `wget-ssl` — 命令行下载
- `htop` — 系统监控
- `nano` — 文本编辑器

**🌍 全中文支持**
- 所有 LuCI 插件均安装中文语言包

---

## 🔄 自动构建

| 触发方式 | 说明 |
|----------|------|
| ⏰ 定时编译 | 每日 UTC 16:00（北京时间 00:00） |
| 🖱️ 手动触发 | Workflow Dispatch |

---

## 📄 许可证

- **OpenWrt** — [GPL-2.0](https://github.com/openwrt/openwrt/blob/main/LICENSE)
- **本项目脚本** — [MIT License](LICENSE)

---

<div align="center">

如果这个项目对您有帮助，请点一个 ⭐ **Star** 支持一下！

Made with ❤️ by [zhuyihua12](https://github.com/zhuyihua12)

</div>
