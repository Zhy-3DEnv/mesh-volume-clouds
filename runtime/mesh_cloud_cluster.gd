@tool
extends Node3D
class_name MeshCloudCluster

## 面向移动端 / VR 的网格实体云团。
## 可指定 Houdini 造型网格（cloud_mesh）；为空时回退 SphereMesh。
## 远距可切换 cloud_mesh_lod。子节点 puff 运行时生成，不写入场景文件。

const _SHADER_FILE: String = "mesh_cloud.gdshader"
const _GENERATED_META: String = "_mesh_cloud_generated"
const _NOISE_OFFSET_META: String = "_mesh_cloud_noise_offset"
## 与 SphereMesh.radius=0.5 对齐的参考半尺寸，用于自定义网格缩放归一化。
const _SPHERE_HALF_EXTENT: float = 0.5

## 单朵云由多少个 puff（子网格）组成。越大团块越密。
@export var puff_count: int = 5:
	set(v):
		puff_count = clampi(v, 1, 12)
		_request_rebuild()

## 云团整体尺度（世界单位近似半径）。
@export var base_radius: float = 8.0:
	set(v):
		base_radius = maxf(v, 0.5)
		_request_rebuild()

## puff 横向散布范围倍率。越大各团块离中心越远。
@export var spread: float = 1.15:
	set(v):
		spread = maxf(v, 0.1)
		_request_rebuild()

## 竖直压扁系数。<1 把云压扁成层状，>1 拉高。
@export var vertical_squash: float = 0.7:
	set(v):
		vertical_squash = clampf(v, 0.15, 1.5)
		_request_rebuild()

## 仅未指定 Cloud Mesh 时生效：程序球体径向/环向细分。有造型网格时自动隐藏。
@export var mesh_segments: int = 14:
	set(v):
		mesh_segments = clampi(v, 8, 24)
		_request_rebuild()

## 随机种子。改变 puff 位置/尺寸的随机布局。
@export var seed: int = 1:
	set(v):
		seed = v
		_request_rebuild()

## 近景高模网格。为空则回退程序 SphereMesh。
@export var cloud_mesh: Mesh:
	set(v):
		cloud_mesh = v
		notify_property_list_changed()
		_request_rebuild()

## 远景低模。需与 Cloud Mesh 同时指定，并开启 LOD 后按距离切换。
@export var cloud_mesh_lod: Mesh:
	set(v):
		cloud_mesh_lod = v
		_using_lod = false
		_update_lod(true)

@export_group("LOD")
## 是否按相机距离在高模 / 低模间切换。
@export var lod_enabled: bool = true:
	set(v):
		lod_enabled = v
		_using_lod = false
		_update_lod(true)

## 超过该距离使用低模（世界单位）。
@export var lod_distance: float = 60.0:
	set(v):
		lod_distance = maxf(v, 1.0)

## 回切高模的滞后距离，避免在切换边界来回抖动。
@export var lod_hysteresis: float = 8.0:
	set(v):
		lod_hysteresis = maxf(v, 0.0)

## 共享着色器材质（直接引用，不 duplicate）。在材质里调色/噪声参数即可实时预览。
@export var cloud_material: ShaderMaterial:
	set(v):
		cloud_material = v
		_fallback_material = null
		if _built and is_inside_tree():
			_reapply_material()
		else:
			_request_rebuild()

var _built: bool = false
var _rebuild_queued: bool = false
## 未指定 cloud_material 时的本地回退材质。
var _fallback_material: ShaderMaterial
var _using_lod: bool = false


func _ready() -> void:
	add_to_group("mesh_cloud_cluster")
	set_process(true)
	_rebuild()


func _enter_tree() -> void:
	set_process(true)
	if Engine.is_editor_hint() and not _built:
		_request_rebuild()


func _validate_property(property: Dictionary) -> void:
	# 自定义造型网格时不显示球体细分参数。
	if property.name == "mesh_segments" and cloud_mesh != null:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _process(_delta: float) -> void:
	# 顶点动画由 shader TIME 驱动；材质直接共享以便 Inspector 实时预览。
	_update_lod(false)
	if Engine.is_editor_hint() and _built:
		_ensure_puffs_use_shared_material()


func _request_rebuild() -> void:
	if not is_inside_tree():
		return
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")


func _shader_path() -> String:
	return get_script().resource_path.get_base_dir().path_join(_SHADER_FILE)


func _ensure_material() -> ShaderMaterial:
	if cloud_material != null:
		return cloud_material
	if _fallback_material != null:
		return _fallback_material
	var shader: Shader = load(_shader_path()) as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo", Color(1.0, 1.0, 1.0, 1.0))
	mat.set_shader_parameter("shadow_color", Color(0.78, 0.8, 0.96, 1.0))
	mat.set_shader_parameter("underside_color", Color(0.82, 0.84, 0.97, 1.0))
	mat.set_shader_parameter("cavity_strength", 0.22)
	mat.set_shader_parameter("height_blend", 0.55)
	mat.set_shader_parameter("brightness", 1.08)
	mat.set_shader_parameter("lit_boost", 1.65)
	mat.set_shader_parameter("light_wrap", 0.55)
	mat.set_shader_parameter("ambient_strength", 1.0)
	mat.set_shader_parameter("rim_color", Color(1.0, 0.98, 0.96, 1.0))
	mat.set_shader_parameter("rim_strength", 0.55)
	mat.set_shader_parameter("rim_power", 2.8)
	mat.set_shader_parameter("rim_lit_bias", 0.35)
	mat.set_shader_parameter("soft_displace_normals", false)
	mat.set_shader_parameter("noise_amp", 0.12)
	mat.set_shader_parameter("noise_scale", 1.4)
	mat.set_shader_parameter("noise_speed", 0.35)
	mat.set_shader_parameter("noise_detail", 0.35)
	_fallback_material = mat
	return _fallback_material


func _reapply_material() -> void:
	var mat: ShaderMaterial = _ensure_material()
	for c: Node in get_children():
		if c is MeshInstance3D and c.has_meta(_GENERATED_META):
			(c as MeshInstance3D).material_override = mat


func _ensure_puffs_use_shared_material() -> void:
	## 若仍挂着旧的 duplicate 材质，拉回共享 cloud_material，保证调参实时可见。
	if cloud_material == null:
		return
	for c: Node in get_children():
		if c is MeshInstance3D and c.has_meta(_GENERATED_META):
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi.material_override != cloud_material:
				mi.material_override = cloud_material


func _resolve_hi_mesh() -> Mesh:
	if cloud_mesh != null:
		return cloud_mesh
	var sphere := SphereMesh.new()
	sphere.radial_segments = mesh_segments
	sphere.rings = maxi(mesh_segments / 2, 6)
	sphere.radius = _SPHERE_HALF_EXTENT
	sphere.height = 1.0
	return sphere


func _resolve_active_mesh() -> Mesh:
	if _should_use_lod():
		return cloud_mesh_lod
	return _resolve_hi_mesh()


func _lod_available() -> bool:
	return lod_enabled and cloud_mesh != null and cloud_mesh_lod != null


func _should_use_lod() -> bool:
	if not _lod_available():
		return false
	var cam: Camera3D = _get_view_camera()
	if cam == null:
		return _using_lod
	var dist: float = global_position.distance_to(cam.global_position)
	if _using_lod:
		return dist > maxf(lod_distance - lod_hysteresis, 0.0)
	return dist > lod_distance


func _get_view_camera() -> Camera3D:
	if Engine.is_editor_hint():
		var ei: Variant = Engine.get_singleton("EditorInterface")
		if ei != null:
			var vp: SubViewport = ei.get_editor_viewport_3d(0)
			if vp != null:
				return vp.get_camera_3d()
		return null
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()


func _mesh_scale_norm(mesh: Mesh) -> float:
	## 尺度始终以高模（或球体）为基准，避免 LOD 切换时整体缩放跳动。
	var ref: Mesh = cloud_mesh if cloud_mesh != null else mesh
	if cloud_mesh == null and mesh is SphereMesh:
		return 1.0
	var aabb: AABB = ref.get_aabb()
	var half: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) * 0.5
	if half < 0.001:
		return 1.0
	return _SPHERE_HALF_EXTENT / half


func _clear_generated() -> void:
	var to_free: Array[Node] = []
	for c: Node in get_children():
		if c.has_meta(_GENERATED_META) or c is MeshInstance3D:
			to_free.append(c)
	for c: Node in to_free:
		remove_child(c)
		c.free()


func _apply_mesh_to_puffs(mesh: Mesh) -> void:
	for c: Node in get_children():
		if c is MeshInstance3D and c.has_meta(_GENERATED_META):
			(c as MeshInstance3D).mesh = mesh


func _update_lod(force: bool) -> void:
	if not is_inside_tree() or not _built:
		return
	if not _lod_available():
		if _using_lod:
			_using_lod = false
			_apply_mesh_to_puffs(_resolve_hi_mesh())
		return
	var want_lod: bool = _should_use_lod()
	if not force and want_lod == _using_lod:
		return
	_using_lod = want_lod
	_apply_mesh_to_puffs(cloud_mesh_lod if want_lod else cloud_mesh)


func _rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	_clear_generated()
	_built = false
	_using_lod = false

	var mat: ShaderMaterial = _ensure_material()
	var hi_mesh: Mesh = _resolve_hi_mesh()
	var scale_norm: float = _mesh_scale_norm(hi_mesh)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# 先按当前相机距离选网格，避免首帧闪高模。
	var want_lod: bool = _lod_available() and _should_use_lod()
	_using_lod = want_lod
	var puff_mesh: Mesh = cloud_mesh_lod if want_lod else hi_mesh

	for i: int in puff_count:
		var mi := MeshInstance3D.new()
		mi.name = "Puff_%d" % i
		mi.set_meta(_GENERATED_META, true)
		mi.mesh = puff_mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transparency = 0.0

		var ox: float = rng.randf_range(-1.0, 1.0) * base_radius * spread * 0.55
		var oy: float = rng.randf_range(-0.35, 0.45) * base_radius * vertical_squash
		var oz: float = rng.randf_range(-1.0, 1.0) * base_radius * spread * 0.55
		if i == 0:
			ox *= 0.15
			oy *= 0.2
			oz *= 0.15

		var sx: float = base_radius * rng.randf_range(0.7, 1.25) * scale_norm
		var sy: float = base_radius * vertical_squash * rng.randf_range(0.55, 0.95) * scale_norm
		var sz: float = base_radius * rng.randf_range(0.7, 1.25) * scale_norm
		if i > 0:
			sx *= rng.randf_range(0.45, 0.85)
			sy *= rng.randf_range(0.5, 0.9)
			sz *= rng.randf_range(0.45, 0.85)

		mi.position = Vector3(ox, oy, oz)
		mi.scale = Vector3(sx, sy, sz)
		mi.rotation_degrees = Vector3(
			rng.randf_range(-12.0, 12.0),
			rng.randf_range(0.0, 360.0),
			rng.randf_range(-12.0, 12.0)
		)
		var n_off := Vector3(
			rng.randf_range(-20.0, 20.0),
			rng.randf_range(-20.0, 20.0),
			rng.randf_range(-20.0, 20.0)
		)
		mi.set_meta(_NOISE_OFFSET_META, n_off)
		mi.set_instance_shader_parameter("noise_offset", n_off)
		add_child(mi)

	_built = true
	_update_lod(true)


func set_sun_direction(_dir: Vector3) -> void:
	pass


func set_anim_time(_t: float) -> void:
	# 顶点动画由 shader TIME 驱动；保留接口兼容旧插件调用。
	pass


## 调试：当前是否处于低模。
func is_using_lod() -> bool:
	return _using_lod
