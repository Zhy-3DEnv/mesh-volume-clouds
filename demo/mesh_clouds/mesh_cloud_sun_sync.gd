extends Node3D

## Pushes directional light direction into all MeshCloudCluster materials.

@export var light_path: NodePath = ^"DirectionalLight3D"


func _ready() -> void:
	_sync_sun()


func _process(_delta: float) -> void:
	_sync_sun()


func _sync_sun() -> void:
	var light := get_node_or_null(light_path) as DirectionalLight3D
	if light == null:
		return
	var dir := -light.global_transform.basis.z
	for n in get_tree().get_nodes_in_group("mesh_cloud_cluster"):
		if n.has_method("set_sun_direction"):
			n.set_sun_direction(dir)
