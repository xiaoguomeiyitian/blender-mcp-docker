#!/bin/sh
# blender-ensure.sh — 让 blender-mcp 栈就绪(幂等,随时可跑,无副作用)
# 处理三种状态:容器被删除 -> 重建;已停止 -> 启动;已在运行 -> 只等端口。
# 就绪后 blender MCP 工具即可正常调用。用法:
#   /root/blender/blender-mcp-docker/blender-ensure.sh
set -u
C=blender-mcp
IMG=blender-mcp:5.2.2
# 硬开关:DISABLED 旗标存在 = owner 已明确禁用本栈，任何调用都不得拉起容器。
# 背景(2026-10-13): 在 MCP 客户端配置里禁用服务器可能只影响新会话;活跃会话
# 仍会按探活节奏 spawn wrapper。若不在脚本层硬拦,容器停机几分钟内就会被拉起。
if [ -f /root/blender/blender-mcp-docker/DISABLED ]; then
  echo "DISABLED: 旗标存在，栈已被禁用；恢复请先 rm /root/blender/blender-mcp-docker/DISABLED" >&2
  exit 1
fi
# 注意:-v 源路径是 docker 宿主机路径(由宿主 daemon 解析)。
# 若 MCP 客户端跑在容器里,其 /root 往往映射宿主机的 /home/coder — 写 /root/... 会得到空的 /work!
HOST_DIR=/home/coder/blender/belend

# 0. 镜像必须存在(没了就按 README 的 Build 一节重建)
if ! docker image inspect "$IMG" >/dev/null 2>&1; then
  echo "ERR: 镜像 $IMG 不存在 — 重建: cd /root/blender/blender-mcp-docker && docker build -t $IMG ."
  exit 1
fi

# 1. 容器被删除 -> 用原 flags 重建(flags 记录于本仓库 README,2026-09-27 实测)
if ! docker container inspect "$C" >/dev/null 2>&1; then
  echo "CREATE: 容器不存在 — 正在重建"
  # unless-stopped(2026-10-10 owner 决策):手动停机在宿主机/docker 重启后保持停机;
  # 自动唤醒由本脚本 + wrapper 承担,不再依赖 always 策略
  if ! docker run -d --name "$C" --restart=unless-stopped \
      --memory=3072m --memory-swap=-1 \
      -v "$HOST_DIR":/work "$IMG"; then
    # 并发竞态:另一个 wrapper 可能恰好刚建好,只要它存在就继续
    docker container inspect "$C" >/dev/null 2>&1 || exit 1
  fi
fi

# 2. 已停止 -> 启动
if [ "$(docker inspect -f '{{.State.Running}}' "$C" 2>/dev/null)" != "true" ]; then
  echo "START: 容器未运行 — 正在启动"
  docker start "$C" || exit 1
fi

# 3. 等插件端口就绪(9876 = hex 2694;冷启动实测 18~40 秒,留 120 秒余量)
i=0
while [ "$i" -lt 60 ]; do
  if docker exec "$C" sh -c 'grep -q ":2694" /proc/net/tcp' 2>/dev/null; then
    echo "READY: blender-mcp 已就绪(等待约 $((i*2)) 秒)"
    exit 0
  fi
  i=$((i+1)); sleep 2
done
echo "ERR: 120 秒后端口仍未就绪 — 检查: docker logs $C"
exit 1
