import bpy

bpy.ops.preferences.addon_enable(module="blender_mcp")
assert "blender_mcp" in bpy.context.preferences.addons, "enable failed"
bpy.ops.wm.save_userpref()
print("ADDON_BAKED_OK")
