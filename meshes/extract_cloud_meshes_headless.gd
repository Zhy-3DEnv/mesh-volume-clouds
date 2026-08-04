extends SceneTree
## 从 GLB 提取 ArrayMesh，并用源 GLB 旁路的 .vnbin 写回正确法线。
## godot --path <项目> --headless -s res://addons/mesh_volume_clouds/meshes/extract_cloud_meshes_headless.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_extract(
		"res://addons/mesh_volume_clouds/meshes/cloud_shape_a.glb",
		"res://addons/mesh_volume_clouds/meshes/cloud_shape_a.vnbin",
		"res://addons/mesh_volume_clouds/meshes/cloud_shape_a.mesh"
	)
	_extract(
		"res://addons/mesh_volume_clouds/meshes/cloud_shape_a_lod.glb",
		"res://addons/mesh_volume_clouds/meshes/cloud_shape_a_lod.vnbin",
		"res://addons/mesh_volume_clouds/meshes/cloud_shape_a_lod.mesh"
	)
	quit(0)


func _extract(glb_path: String, vnbin_path: String, mesh_path: String) -> void:
	var packed: PackedScene = load(glb_path) as PackedScene
	if packed == null:
		push_error("load fail: %s" % glb_path)
		return
	var root: Node = packed.instantiate()
	var mesh: Mesh = _find_mesh(root)
	if mesh == null:
		push_error("no mesh: %s" % glb_path)
		root.free()
		return

	var lookup: Dictionary = _load_vnbin_lookup(vnbin_path)
	if lookup.is_empty():
		push_error("vnbin empty/missing: %s" % vnbin_path)
		root.free()
		return

	var arr_mesh := ArrayMesh.new()
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := PackedVector3Array()
		normals.resize(verts.size())
		var missed: int = 0
		for i: int in verts.size():
			var key: Vector3i = _quant_key(verts[i])
			if lookup.has(key):
				normals[i] = lookup[key] as Vector3
			else:
				# 近邻兜底：量化邻域
				var found: bool = false
				for dx: int in range(-1, 2):
					for dy: int in range(-1, 2):
						for dz: int in range(-1, 2):
							var k2 := Vector3i(key.x + dx, key.y + dy, key.z + dz)
							if lookup.has(k2):
								normals[i] = lookup[k2] as Vector3
								found = true
								break
						if found:
							break
					if found:
						break
				if not found:
					normals[i] = verts[i].normalized() if verts[i].length_squared() > 1e-8 else Vector3.UP
					missed += 1
		arrays[Mesh.ARRAY_NORMAL] = normals
		# 去掉 glTF 自带材质，统一由 cloud_material 控制
		arr_mesh.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays)
		var sample: Vector3 = Vector3.ZERO
		var take: int = mini(normals.size(), 200)
		for i: int in take:
			sample += normals[i]
		print("%s verts=%d missed=%d avg_n=%s" % [glb_path.get_file(), verts.size(), missed, str(sample / float(take))])

	var err: Error = ResourceSaver.save(arr_mesh, mesh_path)
	print("save %s -> %s" % [mesh_path, error_string(err)])
	root.free()


func _load_vnbin_lookup(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var count: int = f.get_32()
	var lookup: Dictionary = {}
	# 先读完所有 pos
	var positions := PackedVector3Array()
	positions.resize(count)
	for i: int in count:
		positions[i] = Vector3(f.get_float(), f.get_float(), f.get_float())
	for i: int in count:
		var n := Vector3(f.get_float(), f.get_float(), f.get_float())
		if n.length_squared() > 1e-12:
			n = n.normalized()
		else:
			n = Vector3.UP
		lookup[_quant_key(positions[i])] = n
	f.close()
	return lookup


func _quant_key(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 10000.0), roundi(v.y * 10000.0), roundi(v.z * 10000.0))


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
