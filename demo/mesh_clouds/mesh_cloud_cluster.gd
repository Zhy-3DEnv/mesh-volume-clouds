@tool
extends Node3D
class_name MeshCloudCluster

## Procedural multi-puff mesh cloud for mobile / VR friendly fake volume.

@export var puff_count: int = 5:
	set(v):
		puff_count = clampi(v, 1, 12)
		if is_inside_tree():
			_rebuild()

@export var base_radius: float = 900.0:
	set(v):
		base_radius = maxf(v, 10.0)
		if is_inside_tree():
			_rebuild()

@export var spread: float = 1.15:
	set(v):
		spread = maxf(v, 0.1)
		if is_inside_tree():
			_rebuild()

@export var vertical_squash: float = 0.55:
	set(v):
		vertical_squash = clampf(v, 0.15, 1.5)
		if is_inside_tree():
			_rebuild()

@export var mesh_segments: int = 14:
	set(v):
		mesh_segments = clampi(v, 8, 24)
		if is_inside_tree():
			_rebuild()

@export var seed: int = 1:
	set(v):
		seed = v
		if is_inside_tree():
			_rebuild()

@export var cloud_material: ShaderMaterial

var _built: bool = false


func _ready() -> void:
	add_to_group("mesh_cloud_cluster")
	_rebuild()


func _ensure_material() -> ShaderMaterial:
	if cloud_material != null:
		return cloud_material
	var shader := load("res://demo/mesh_clouds/mesh_cloud.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo", Color(0.98, 0.99, 1.0, 0.92))
	mat.set_shader_parameter("underside_color", Color(0.62, 0.68, 0.78, 1.0))
	mat.set_shader_parameter("density", 1.4)
	mat.set_shader_parameter("soft_edge", 1.7)
	mat.set_shader_parameter("edge_erosion", 0.9)
	mat.set_shader_parameter("fluff", 0.95)
	mat.set_shader_parameter("center_fill", 0.7)
	mat.set_shader_parameter("displacement_amp", 0.4)
	mat.set_shader_parameter("displacement_scale", 1.55)
	mat.set_shader_parameter("displacement_speed", 0.08)
	mat.set_shader_parameter("sun_direction", Vector3(0.35, 0.65, -0.5).normalized())
	cloud_material = mat
	return mat


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_built = false

	var mat := _ensure_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	for i in puff_count:
		var mi := MeshInstance3D.new()
		mi.name = "Puff_%d" % i
		var sphere := SphereMesh.new()
		sphere.radial_segments = mesh_segments
		sphere.rings = maxi(mesh_segments / 2, 6)
		sphere.radius = 0.5
		sphere.height = 1.0
		mi.mesh = sphere
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var ox := rng.randf_range(-1.0, 1.0) * base_radius * spread * 0.55
		var oy := rng.randf_range(-0.35, 0.45) * base_radius * vertical_squash
		var oz := rng.randf_range(-1.0, 1.0) * base_radius * spread * 0.55
		# Keep first puff near center as the mass core.
		if i == 0:
			ox *= 0.15
			oy *= 0.2
			oz *= 0.15

		var sx := base_radius * rng.randf_range(0.7, 1.25)
		var sy := base_radius * vertical_squash * rng.randf_range(0.55, 0.95)
		var sz := base_radius * rng.randf_range(0.7, 1.25)
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
		add_child(mi)
		if Engine.is_editor_hint():
			mi.owner = get_tree().edited_scene_root

	_built = true


func set_sun_direction(dir: Vector3) -> void:
	var mat := _ensure_material()
	mat.set_shader_parameter("sun_direction", dir.normalized())
