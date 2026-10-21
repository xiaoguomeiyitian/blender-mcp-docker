#!/bin/sh
# blender-mcp-wrapper.sh — blender MCP 服务器的自动唤醒包装器
# 作为 MCP 客户端配置里 blender 服务器的 command 使用:每次 MCP 工具调用都会先确保
# blender-mcp 容器存在且就绪(被删→重建 / 停了→启动 / 端口未就绪→等待),
# 再把 stdio 转接给容器内的 mcp-for-blender。
# 输出纪律:ensure 阶段必须完全静默 —— MCP JSON-RPC 走 stdout,一个字节都不能污染。
# 注:docker exec 不会转发客户端环境变量,故用 -e 显式传入 DISABLE_TELEMETRY。
#
# 通用 MCP 通道(2026-10-21 双通道解耦):任何 agent 工具配本文件即连。
# DSH 通道(blender-dsh)不经此脚本。
set -u
C=${BLENDER_CONT:-blender-mcp}
HERE=$(cd "$(dirname "$0")" && pwd)
DISABLED_FLAG=${DISABLED_FLAG:-$HERE/DISABLED}

# 硬开关(与 ensure 内检查一致): DISABLED 旗标存在时静默退出 —— MCP 客户端
# 得到立即 EOF(= 服务器不可用)，绝不会触碰容器。
if [ -f "$DISABLED_FLAG" ]; then
  exit 0
fi
"$HERE/blender-ensure.sh" >/dev/null 2>&1 || true
exec docker exec -i -e "DISABLE_TELEMETRY=${DISABLE_TELEMETRY:-true}" "$C" /root/.local/bin/mcp-for-blender
