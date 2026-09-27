#!/bin/sh
# blender-mcp 容器入口:Xvfb 假显示 + Blender GUI(addon 自动绑 localhost:9876)
rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 1280x800x24 -nolisten tcp &
sleep 1
export DISPLAY=:99
if [ -f /work/workspace.blend ]; then
    exec blender /work/workspace.blend --python /opt/autosave.py
fi
exec blender --python /opt/autosave.py
