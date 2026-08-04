@tool
extends EditorScript
## 从 GLB PackedScene 提取 ArrayMesh（含法线），保存为 .mesh，供 MeshCloudCluster 直接引用。
## 在脚本编辑器中打开本文件 → 文件 → 运行。


func _run() -> void:
	_extract(
		"res://addons/mesh_volume_clouds/meshes/cloud_shape_a.glb",
		"res://addons/mesh_volume_clouds/meshes/cloud_shape_a.mesh"
	)
	_extract(
		"res://addons/mesh_volume_clouds/meshes/cloud_shape_a_lod.glb",
		"res://addons/mesh_volume_clouds/meshes/cloud_shape_a_lod.mesh"
	)
	print("extract_meshes_from_glb: done")


func _extract(glb_path: String, mesh_path: String) -> void:
	var packed: PackedScene = load(glb_path) as PackedScene
	if packed == null:
		push_error("无法加载: %s" % glb_path)
		return
	var root: Node = packed.instantiate()
	var mesh: Mesh = _find_mesh(root)
	if mesh == null:
		push_error("未找到 Mesh: %s" % glb_path)
		root.free()
		return
	var arr_mesh: ArrayMesh = mesh as ArrayMesh
	if arr_mesh == null:
		# 复制为 ArrayMesh
		arr_mesh = ArrayMesh.new()
		for s: int in mesh.get_surface_count():
			arr_mesh.add_surface_from_arrays(
				mesh.surface_get_primitive_type(s),
				mesh.surface_get_arrays(s)
			)
	for s: int in arr_mesh.get_surface_count():
		var arrays: Array = arr_mesh.surface_get_arrays(s)
		var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
		var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		var n_count: int = normals.size() if normals != null else 0
		var v_count: int = verts.size() if verts != null else 0
		print("%s surface%d verts=%d normals=%d" % [glb_path.get_file(), s, v_count, n_count])
		if n_count == 0:
			push_warning("表面无 ARRAY_NORMAL，将按面重算法线: %s" % glb_path)
			_rebuild_normals(arr_mesh, s)
	var err: Error = ResourceSaver.save(arr_mesh, mesh_path)
	if err != OK:
		push_error("保存失败 %s err=%s" % [mesh_path, error_string(err)])
	else:
		print("已保存: ", mesh_path)
	root.free()


func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			return mi.mesh
	for c: Node in node.get_children():
		var found: Mesh = _find_mesh(c)
		if found != null:
			return found
	return null


func _rebuild_normals(mesh: ArrayMesh, surface: int) -> void:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i: int in normals.size():
		normals[i] = Vector3.ZERO
	if indices.is_empty():
		var i: int = 0
		while i + 2 < verts.size():
			var a: Vector3 = verts[i]
			var b: Vector3 = verts[i + 1]
			var c: Vector3 = verts[i + 2]
			var fn: Vector3 = (b - a).cross(c - a)
			normals[i] += fn
			normals[i + 1] += fn
			normals[i + 2] += fn
			i += 3
	else:
		var i: int = 0
		while i + 2 < indices.size():
			var ia: int = indices[i]
			var ib: int = indices[i + 1]
			var ic: int = indices[i + 2]
			var fn: Vector3 = (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
			normals[ia] += fn
			normals[ib] += fn
			normals[ic] += fn
			i += 3
	for i: int in normals.size():
		if normals[i].length_squared() < 1e-12:
			normals[i] = Vector3.UP
		else:
			normals[i] = normals[i].normalized()
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mat: Material = mesh.surface_get_material(surface)
	mesh.clear_surfaces()
	# 只能重建整个 mesh 时较麻烦；此处仅处理单 surface 情况。
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mat != null:
		mesh.surface_set_material(0, mat)
