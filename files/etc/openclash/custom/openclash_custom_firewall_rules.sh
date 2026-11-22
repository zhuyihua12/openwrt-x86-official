#!/bin/sh
. /usr/share/openclash/log.sh
. /lib/functions/uci-defaults.sh 2>/dev/null || true

# 本脚本由 /etc/init.d/openclash 在启动末尾调用。
# 当前无定制规则（原 ZeroTier UDP 9993 免劫持规则已随组件于 2026-11 移除）。

LOG_TIP "Start Add Custom Firewall Rules..."
LOG_TIP "No custom rules configured."
LOG_TIP "OpenClash Custom Firewall Rules Script Completed!"
