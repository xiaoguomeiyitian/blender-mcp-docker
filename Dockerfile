FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive

# X11/GL/Xvfb: Blender GUI 必需;--no-install-recommends 下 libglx-mesa0/libgl1-mesa-dri
# (llvmpipe 软件渲染)不会被自动带入,必须显式列出
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb xz-utils curl ca-certificates procps \
    libx11-6 libxi6 libxxf86vm1 libxfixes3 libxrender1 \
    libgl1 libglx-mesa0 libgl1-mesa-dri \
    libsm6 libice6 libxkbcommon0 libegl1 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Blender 5.2.2 LTS,解压后删包
RUN curl -L -o /tmp/b.tar.xz \
      https://download.blender.org/release/Blender5.2/blender-5.2.2-linux-x64.tar.xz \
    && tar -xf /tmp/b.tar.xz -C /opt && rm /tmp/b.tar.xz
ENV PATH="/opt/blender-5.2.2-linux-x64:${PATH}"

# uv + MCP server(pin 2.1.0;uv 会自动拉一个托管 CPython,容器无需系统 python)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"
RUN uv tool install mcp-for-blender==2.1.0

# addon 落盘 + 无头启用,烘焙进镜像(background 只禁 server 启动,不禁 enable)
COPY enable.py /tmp/enable.py
COPY autosave.py /opt/autosave.py
RUN mkdir -p /root/.config/blender/5.2/scripts/addons \
    && mcp-for-blender install-addon \
    && blender -b -P /tmp/enable.py \
    && rm /tmp/enable.py

COPY start.sh /start.sh
RUN chmod +x /start.sh
CMD ["/start.sh"]
