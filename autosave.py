# 每 10 分钟自动保存场景到 /work/workspace.blend(用户批准的决策点②)
# persistent=True: 跨文件加载存活;timer 在 Blender 主线程跑,save 操作线程安全
import bpy

_SAVE_PATH = "/work/workspace.blend"
_INTERVAL = 600.0


def _autosave():
    try:
        bpy.ops.wm.save_as_mainfile(filepath=_SAVE_PATH)
        print("AUTOSAVE_OK")
    except Exception as e:
        print(f"AUTOSAVE_FAIL: {e}")
    return _INTERVAL


bpy.app.timers.register(_autosave, first_interval=_INTERVAL, persistent=True)
print("AUTOSAVE_TIMER_REGISTERED(600s)")
