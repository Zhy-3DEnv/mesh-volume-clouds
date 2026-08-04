# Mesh Volume Clouds

面向 **移动端 / VR** 的网格假体积云 Godot 编辑器插件（Godot **4.7**，Mobile / Forward+）。

由 Sunshine 全屏体积云方案切换而来：用多层造型网格 + 顶点动画 + Shader 模拟云感，帧率更可预期。

## 安装

1. 将本目录放到项目的 `addons/mesh_volume_clouds/`
2. 项目设置 → 插件 → 启用 **Mesh Volume Clouds**
3. 在场景中添加 `MeshCloudCluster` / `MeshCloudSunSync`，或打开演示场景：
   - `res://addons/mesh_volume_clouds/demo/mesh_clouds_demo.tscn`

仓库：https://github.com/Zhy-3DEnv/mesh-volume-clouds

## 目录结构

```
mesh_volume_clouds/
├── plugin.cfg
├── plugin.gd
├── README.md
├── meshes/                     # Houdini 造型网格
│   ├── cloud_shape_a.glb (+ .vnbin)       # 直接引用；vnbin 修复导入法线
│   └── cloud_shape_a_lod.glb (+ .vnbin)
├── runtime/
│   ├── mesh_cloud.gdshader                 # 实体风（不透明）
│   ├── mesh_cloud_sky_style.gdshader       # Sky 风格（透明软边，吸收 Unity SkyClouds）
│   ├── mesh_cloud_cluster.gd
│   ├── mesh_cloud_sun_sync.gd
│   ├── mesh_cloud_material.tres
│   └── mesh_cloud_sky_style_material.tres
├── demo/
│   ├── mesh_clouds_demo.tscn              # 球体 puff 原型
│   ├── mesh_clouds_shaped_demo.tscn       # Houdini 造型 + 实体材质
│   ├── mesh_clouds_sky_style_demo.tscn    # 造型 + Sky 风格材质
│   └── flythrough_camera.gd
└── docs/
    └── DEVELOPMENT.md
```

## 快速用法

1. 场景根（或环境节点）挂 `MeshCloudSunSync`，并指定 `DirectionalLight3D` 路径
2. 在 `Clouds` 下添加若干 `MeshCloudCluster`，调整 `puff_count` / `base_radius` / `seed`
3. 造型云：`cloud_mesh` = 高模，`cloud_mesh_lod` = 低模；开启 `lod_enabled` 后按 `lod_distance` 切换
4. 多个云团建议共享同一 `ShaderMaterial`（`runtime/mesh_cloud_material.tres`）；材质**不再 duplicate**，Inspector 改参数可实时预览

演示场景：
- 球体原型：`demo/mesh_clouds_demo.tscn`
- Houdini 造型（实体）：`demo/mesh_clouds_shaped_demo.tscn`
- Sky 风格（透明软边）：`demo/mesh_clouds_sky_style_demo.tscn`

编辑器：
- **聚焦云**：对准云团
- **云动画:开**：强制编辑器持续重绘（`update_continuously`），否则 shader 的 `TIME` 不前进、顶点动画看起来是静止的

材质两套：
- **实体风** `mesh_cloud_material.tres`：不透明，白顶/淡紫 + wrap 光照
- **Sky 风格** `mesh_cloud_sky_style_material.tres`：透明软边 + Voronoi/Noise 位移 + 透光 + 可选 Depth Fade（默认关）

运行：自动沿航点飞行；点击屏幕暂停/继续；右上角显示 FPS。

## 设计要点

| 目标 | 做法 |
|------|------|
| 高空可见、可俯视/穿云 | 真实 3D 网格，不是半球天空 |
| 移动端 / VR 友好 | Mobile 渲染器；无全屏 raymarch |
| 云感 | 多层 puff + 顶点位移 + 软边/透光/银边 Shader |

更细说明见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)。

## 许可证

工程内代码按项目需要自行约定；图标来自 Godot 默认资源风格。
