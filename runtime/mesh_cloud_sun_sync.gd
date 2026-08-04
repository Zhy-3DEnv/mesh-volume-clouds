@tool
extends Node3D
class_name MeshCloudSunSync

## 兼容旧场景的挂载点。云已改为接收场景 DirectionalLight / 环境光，无需再写 sun_direction。
## 若场景根仍挂此脚本可保留，不影响表现。

@export var light_path: NodePath = ^"DirectionalLight3D"


func _ready() -> void:
	pass
