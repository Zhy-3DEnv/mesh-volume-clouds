@tool
extends EditorPlugin
## 网格假体积云插件：注册节点、聚焦预览。
## 编辑器顶点动画依赖「持续更新」——否则 3D 视口不重绘，TIME 不前进。

const CLUSTER_SCRIPT: Script = preload("res://addons/mesh_volume_clouds/runtime/mesh_cloud_cluster.gd")
const SUN_SYNC_SCRIPT: Script = preload("res://addons/mesh_volume_clouds/runtime/mesh_cloud_sun_sync.gd")
const _SETTING_UPDATE_CONTINUOUSLY: String = "interface/editor/update_continuously"

var _focus_btn: Button
var _anim_btn: Button
var _preview_anim: bool = true
var _saved_update_continuously: Variant = null
var _continuous_forced: bool = false


func _enter_tree() -> void:
	add_custom_type("MeshCloudCluster", "Node3D", CLUSTER_SCRIPT, null)
	add_custom_type("MeshCloudSunSync", "Node3D", SUN_SYNC_SCRIPT, null)

	_focus_btn = Button.new()
	_focus_btn.text = "聚焦云"
	_focus_btn.tooltip_text = "将 3D 视口相机对准当前场景中的 MeshCloudCluster"
	_focus_btn.pressed.connect(_on_focus_clouds)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _focus_btn)

	_anim_btn = Button.new()
	_anim_btn.toggle_mode = true
	_anim_btn.button_pressed = true
	_anim_btn.text = "云动画:开"
	_anim_btn.tooltip_text = "开启后强制编辑器持续重绘，才能看到 shader 顶点噪声动画（会略增编辑器功耗）"
	_anim_btn.toggled.connect(_on_anim_preview_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _anim_btn)

	set_process(true)


func _exit_tree() -> void:
	set_process(false)
	_restore_update_continuously()
	if _focus_btn != null:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _focus_btn)
		_focus_btn.queue_free()
		_focus_btn = null
	if _anim_btn != null:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _anim_btn)
		_anim_btn.queue_free()
		_anim_btn = null
	remove_custom_type("MeshCloudCluster")
	remove_custom_type("MeshCloudSunSync")


func _process(_delta: float) -> void:
	var has_clouds: bool = not _get_edited_clusters().is_empty()
	var want_continuous: bool = _preview_anim and has_clouds
	if want_continuous:
		_force_update_continuously()
		_force_viewport_always_update()
	else:
		_restore_update_continuously()


func _on_anim_preview_toggled(pressed: bool) -> void:
	_preview_anim = pressed
	_anim_btn.text = "云动画:开" if pressed else "云动画:关"
	if not pressed:
		_restore_update_continuously()


func _force_update_continuously() -> void:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return
	if not _continuous_forced:
		_saved_update_continuously = settings.get_setting(_SETTING_UPDATE_CONTINUOUSLY)
		_continuous_forced = true
	if settings.get_setting(_SETTING_UPDATE_CONTINUOUSLY) != true:
		settings.set_setting(_SETTING_UPDATE_CONTINUOUSLY, true)


func _restore_update_continuously() -> void:
	if not _continuous_forced:
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings != null and _saved_update_continuously != null:
		settings.set_setting(_SETTING_UPDATE_CONTINUOUSLY, _saved_update_continuously)
	_saved_update_continuously = null
	_continuous_forced = false


func _force_viewport_always_update() -> void:
	for i: int in 4:
		var vp: SubViewport = EditorInterface.get_editor_viewport_3d(i)
		if vp == null:
			continue
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		RenderingServer.viewport_set_update_mode(
			vp.get_viewport_rid(),
			RenderingServer.VIEWPORT_UPDATE_ALWAYS
		)


func _get_edited_clusters() -> Array[Node]:
	var root: Node = EditorInterface.get_edited_scene_root()
	var found: Array[Node] = []
	if root != null:
		_collect_clusters(root, found)
	return found


func _on_focus_clouds() -> void:
	var clusters: Array[Node] = _get_edited_clusters()
	if clusters.is_empty():
		push_warning("Mesh Volume Clouds: 场景中没有 MeshCloudCluster")
		return
	var aabb := AABB()
	var has_aabb: bool = false
	for c: Node in clusters:
		if c is Node3D:
			var n3: Node3D = c as Node3D
			var local_aabb := AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
			if c.get("base_radius") != null:
				var r: float = float(c.get("base_radius")) * 1.6
				local_aabb = AABB(Vector3(-r, -r * 0.7, -r), Vector3(r * 2.0, r * 1.4, r * 2.0))
			var world_aabb: AABB = n3.global_transform * local_aabb
			if not has_aabb:
				aabb = world_aabb
				has_aabb = true
			else:
				aabb = aabb.merge(world_aabb)
	EditorInterface.get_selection().clear()
	for c: Node in clusters:
		EditorInterface.get_selection().add_node(c)
	var cam: Camera3D = EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	if cam != null and has_aabb:
		var center: Vector3 = aabb.get_center()
		var size: float = maxf(aabb.size.length(), 2.0)
		var dir: Vector3 = Vector3(0.55, 0.35, 0.75).normalized()
		cam.global_position = center + dir * size * 1.35
		cam.look_at(center, Vector3.UP)


func _is_cluster_node(n: Node) -> bool:
	if n is MeshCloudCluster:
		return true
	var scr: Script = n.get_script() as Script
	if scr == null:
		return false
	if scr == CLUSTER_SCRIPT:
		return true
	var path: String = scr.resource_path
	return path.ends_with("mesh_cloud_cluster.gd")


func _collect_clusters(n: Node, out: Array[Node]) -> void:
	if _is_cluster_node(n):
		out.append(n)
	for child: Node in n.get_children():
		_collect_clusters(child, out)
