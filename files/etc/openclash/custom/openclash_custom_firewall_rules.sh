#!/bin/sh
. /usr/share/openclash/log.sh
. /lib/functions/uci-defaults.sh 2>/dev/null || true

# 本脚本由 /etc/init.d/openclash 在启动末尾调用。
# 固件定制：ZeroTier 免劫持白名单。
#
# 原理：OpenClash 的 TProxy 链(openclash_mangle/_v6)劫持全部 UDP，
# 会把 ZeroTier 节点间的 UDP 9993 打洞流量送进 mihomo，导致远程组网
# 只剩高延迟中继甚至断连。此处把源/目的端口 9993 的 UDP 排除在劫持外。

zt_pass() {
	chain=$1
	nft list chain inet fw4 "$chain" 2>/dev/null | grep -q "sport 9993" || \
		nft insert rule inet fw4 "$chain" meta l4proto udp udp sport 9993 return 2>/dev/null
	nft list chain inet fw4 "$chain" 2>/dev/null | grep -q "dport 9993" || \
		nft insert rule inet fw4 "$chain" meta l4proto udp udp dport 9993 return 2>/dev/null
}

LOG_TIP "Start Add Custom Firewall Rules..."
zt_pass openclash_mangle
zt_pass openclash_mangle_v6
LOG_TIP "ZeroTier UDP 9993 bypass rules installed."
LOG_TIP "OpenClash Custom Firewall Rules Script Completed!"
