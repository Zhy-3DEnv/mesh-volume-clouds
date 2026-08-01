@tool
extends Node3D
class_name MeshCloudSunSync

## 将平行光方向写入所有 MeshCloudCluster 材质。

@export var light_path: NodePath = ^"DirectionalLight3D"


func _ready() -> void:
	_sync_sun()


func _process(_delta: float) -> void:
	_sync_sun()


func _sync_sun() -> void:
	var light: DirectionalLight3D = get_node_or_null(light_path) as DirectionalLight3D
	if light == null:
		return
	var dir: Vector3 = -light.global_transform.basis.z
	for n: Node in get_tree().get_nodes_in_group("mesh_cloud_cluster"):
		if n.has_method("set_sun_direction"):
			n.call("set_sun_direction", dir)
