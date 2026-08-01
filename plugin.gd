@tool
extends EditorPlugin
## 网格假体积云插件入口：注册自定义节点类型，便于在编辑器中创建云团。

const CLUSTER_SCRIPT: Script = preload("res://addons/mesh_volume_clouds/runtime/mesh_cloud_cluster.gd")
const SUN_SYNC_SCRIPT: Script = preload("res://addons/mesh_volume_clouds/runtime/mesh_cloud_sun_sync.gd")


func _enter_tree() -> void:
	add_custom_type("MeshCloudCluster", "Node3D", CLUSTER_SCRIPT, null)
	add_custom_type("MeshCloudSunSync", "Node3D", SUN_SYNC_SCRIPT, null)


func _exit_tree() -> void:
	remove_custom_type("MeshCloudCluster")
	remove_custom_type("MeshCloudSunSync")
