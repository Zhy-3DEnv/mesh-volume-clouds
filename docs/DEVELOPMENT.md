# 网格体积云 — 开发文档（插件版）

## 1. 背景与目标

### 1.1 已停用方向

- **Sunshine Clouds 2**：真体积 raymarch，穿云/俯视能力强，但 Adreno 上对着云帧率偏低。
- **Clayjohn 半球天空体积**：性能好，但不适合高空俯视与穿云。

### 1.2 当前方向

**网格假体积云（Mesh Fake Volume Clouds）** — 以 Godot EditorPlugin 形式分发。

- 每朵云 = 多个扁球体 / 后续可换成云造型网格
- Shader：软边 alpha、顶亮底灰、透光、银边、噪声侵蚀轮廓
- 顶点：FBM + cellular 位移，缓慢翻滚
- 目标平台：Android（Forward Mobile）、VR

## 2. 架构

```
MeshCloudsDemo (Node3D + MeshCloudSunSync)
├── WorldEnvironment / DirectionalLight3D / Ground
├── FloatingIslands
├── Clouds
│   ├── Cloud1..Cloud5       # MeshCloudCluster
│   │     └── Puff_0..N      # SphereMesh + 共享 ShaderMaterial
└── Camera3D                 # flythrough_camera.gd（仅 demo）
```

### 核心脚本

| 文件 | 作用 |
|------|------|
| `runtime/mesh_cloud_cluster.gd` | 按 seed 生成多 puff；支持 `cloud_mesh` 造型网格 |
| `runtime/mesh_cloud.gdshader` | 实体风外观与动画（不透明） |
| `runtime/mesh_cloud_sky_style.gdshader` | Sky 风格：吸收 Unity SkyClouds（无 Tess）— Voronoi/Noise 位移、透明软边、透光、可选 Depth Fade |
| `runtime/mesh_cloud_sun_sync.gd` | 兼容挂载点（现已走场景灯） |
| `plugin.gd` | 注册自定义节点类型 |

群组：`mesh_cloud_cluster`（用于太阳方向同步）。

### Houdini 造型网格

| 文件 | SOP | 约三角数 |
|------|-----|----------|
| `meshes/cloud_shape_a.glb` | `/obj/geo1/normal_lod0` | ~50k tris |
| `meshes/cloud_shape_a_lod.glb` | `/obj/geo1/normal_lod1` | ~10k tris |

`cloud_mesh` / `cloud_mesh_lod` **直接拖 GLB** 即可。Godot 导入 GLB 易弄坏法线，Cluster 会在解析时用同名 `.vnbin`（或拓扑重算）修复。  
LOD：`lod_enabled` + `cloud_mesh_lod` 时，相对相机距离 > `lod_distance` 换低模；回切带 `lod_hysteresis`；只换 `MeshInstance3D.mesh`，不重建整团。

材质卡参考：**高调实体爆米花云**（亮白/淡紫固有色 + `diffuse_lambert_wrap`，**接收场景灯光与环境光**）。

顶点动画：`noise_amp` 为相对局部半径比例（解决 Houdini 大网格位移看不见的问题）；`anim_time` 写在材质运行时副本上。编辑器由插件每帧推进并强制视口刷新。

编辑器预览：
- 演示场景云团放在原点附近，打开即可看见
- 3D 视口菜单按钮 **聚焦云** 可对准所有 `MeshCloudCluster`
- 生成的 puff 不写入 `.tscn`，由 `@tool` 实时重建
- 修改插件脚本后需开关一次插件以重载

重新导出：输出 **GLB** 到 `meshes/cloud_shape_a.glb` / `cloud_shape_a_lod.glb`（Houdini ROP 或等价流程）。

## 3. Shader / 云团参数

### 3.1 实体风 `mesh_cloud.gdshader`

不透明；`albedo` / `shadow_color` / `underside_color` + wrap 漫反射 + rim。

### 3.2 Sky 风格 `mesh_cloud_sky_style.gdshader`

参考 Kamgam SkyCloudsURP（Mobile 无 Tessellation）移植要点：
- 顶点：3D FBM + Voronoi FBM，沿法线位移，风向 `wind_direction` / `wind_speed`
- 片元：`ALPHA` 软边（Fresnel + 噪声侵蚀）；`depth_fade_enabled` 可选采深度
- 光照：wrap 漫反射 + 背光透光项（Translucency）
- **刻意不做** GPU Tessellation（Mobile / Quest）

Demo：`demo/mesh_clouds_sky_style_demo.tscn`（少量云，降低透明 Overdraw）。

## 4. 性能注意

- 半透明 overdraw 是主要成本：控制 puff 数量与屏幕覆盖（Sky 风格尤甚）
- Depth Fade 默认关闭；Quest 上慎开
- 关闭云阴影（脚本已 `SHADOW_CASTING_SETTING_OFF`）
- 共享同一 `ShaderMaterial` 便于合批
- VR：注意双眼填充与半透明排序，优先少层、远距降段数

## 5. 路线图

1. ~~造型：用真正的云状网格替换 SphereMesh~~（已接入 `cloud_shape_a`）
2. ~~LOD：按距离切换 `cloud_mesh_lod`~~（`lod_enabled` / `lod_distance` / `lod_hysteresis`）
3. ~~Sky 风格 Shader（吸收 Unity SkyClouds Mobile）~~
4. 近景：穿云时加轻雾/粒子壳
5. VR：OpenXR 场景适配
5. 美术：厚度图 / 噪声贴图代替部分程序噪声
6. 多造型库：B/C 变体与随机抽取

## 6. 分支约定

- `main`：独立演示工程（历史形态）
- `addon`：仅包含插件化目录内容（可直接放到 `addons/mesh_volume_clouds/`）
