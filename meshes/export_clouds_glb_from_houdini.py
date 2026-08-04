# 在 Houdini Python Shell 中运行（需已打开含 /obj/geo1 的云造型 hip）：
#   exec(open(r'e:/Godot Project/Dragon_Ace_Godot/addons/mesh_volume_clouds/meshes/export_clouds_glb_from_houdini.py').read())
#
# 导出带 Point Normal 的 GLB 到本目录。

import os

OUT_DIR = r"e:/Godot Project/Dragon_Ace_Godot/addons/mesh_volume_clouds/meshes"
os.makedirs(OUT_DIR, exist_ok=True)

geo1 = hou.node("/obj/geo1")
if geo1 is None:
	raise RuntimeError("找不到 /obj/geo1，请先打开云造型场景")

# MeshClouds.hip 当前显示节点为 normal_lod0；另一档为 normal_lod1
normal_hi = hou.node("/obj/geo1/normal_lod0")
normal_lod = hou.node("/obj/geo1/normal_lod1")
if normal_hi is None:
	raise RuntimeError("找不到 /obj/geo1/normal_lod0（请确认 MeshClouds.hip）")
if normal_lod is None:
	raise RuntimeError("找不到 /obj/geo1/normal_lod1")

# 确保输出点法线
for n in (normal_hi, normal_lod):
	if n.parm("type") is not None:
		n.parm("type").set(0)  # 0 = Points（常见）
	if n.parm("overwrite") is not None:
		n.parm("overwrite").set(True)

out = hou.node("/out")
if out is None:
	out = hou.node("/").createNode("ropnet", "out")


def _export_with_gltf(sop_path, file_path, rop_name):
	"""优先 glTF ROP；没有则用 geometry ROP 出临时 obj 再提示。"""
	rop = out.node(rop_name)
	# 尝试常见 glTF ROP 类型名
	created = False
	if rop is None:
		for tname in ("gltf", "rop_gltf", "glTF", "sidefx::gltf"):
			try:
				rop = out.createNode(tname, rop_name)
				created = True
				break
			except Exception:
				rop = None
	if rop is not None and created:
		print("使用 ROP 类型:", rop.type().name())

	if rop is not None and "gltf" in rop.type().name().lower():
		# 参数名因版本而异，尽量兼容
		for pname, val in (
			("soppath", sop_path),
			("filepath", file_path),
			("file", file_path),
			("filename", file_path),
			("exportpath", file_path),
		):
			p = rop.parm(pname)
			if p is not None:
				p.set(val)
		# 尽量打开法线导出
		for pname in ("exportnormals", "normals", "pointdata"):
			p = rop.parm(pname)
			if p is not None:
				try:
					p.set(1)
				except Exception:
					pass
		rop.render()
		return True

	# 回退：geometry ROP -> .bgeo.sc 不够；用 File SOP 写 glb 不可靠。
	# 使用 lab / 内置：通过 hou.Geometry.saveToFile 需要 cook geometry。
	return False


def _export_via_geometry_save(sop_node, file_path):
	"""Cook SOP 后用 gusd/gltf 不可用时，写 OBJ（带 vn）再转。优先直接 glb。"""
	geo = sop_node.geometry()
	# Houdini 19+ 部分版本支持 geo.saveToFile('.glb')
	ext = os.path.splitext(file_path)[1].lower()
	try:
		geo.saveToFile(file_path)
		print("saveToFile OK:", file_path)
		return True
	except Exception as e:
		print("saveToFile 失败:", e)
		# 回退 OBJ（含 vn）
		obj_path = file_path.replace(".glb", ".obj")
		geo.saveToFile(obj_path)
		print("已写 OBJ（含法线）:", obj_path, "请再转 GLB 或告知 AI 转换")
		return False


jobs = (
	(normal_hi, os.path.join(OUT_DIR, "cloud_shape_a.glb"), "mcp_export_hi_glb"),
	(normal_lod, os.path.join(OUT_DIR, "cloud_shape_a_lod.glb"), "mcp_export_lod_glb"),
)

for sop, path, rop_name in jobs:
	path = path.replace("\\", "/")
	ok = _export_with_gltf(sop.path(), path, rop_name)
	if not ok:
		print("无 glTF ROP，改用 geometry.saveToFile:", sop.path())
		_export_via_geometry_save(sop, path)
	else:
		print("导出完成:", path)

print("完成。回到 Godot 对 meshes/*.glb 执行 Reimport。")
