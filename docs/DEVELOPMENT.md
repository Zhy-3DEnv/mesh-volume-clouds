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
| `runtime/mesh_cloud_cluster.gd` | 按 seed 生成多 puff |
| `runtime/mesh_cloud.gdshader` | 外观与动画 |
| `runtime/mesh_cloud_sun_sync.gd` | 平行光方向写入云材质 |
| `plugin.gd` | 注册自定义节点类型 |

群组：`mesh_cloud_cluster`（用于太阳方向同步）。

## 3. Shader / 云团参数

见原演示工程说明；材质参数与 `MeshCloudCluster` 导出项未变。

## 4. 性能注意

- 半透明 overdraw 是主要成本：控制 puff 数量与屏幕覆盖
- 关闭云阴影（脚本已 `SHADOW_CASTING_SETTING_OFF`）
- 共享同一 `ShaderMaterial` 便于合批
- VR：注意双眼填充与半透明排序，优先少层、远距降段数

## 5. 路线图

1. 造型：用真正的云状网格替换 SphereMesh
2. LOD：远距减少 puff / 段数
3. 近景：穿云时加轻雾/粒子壳
4. VR：OpenXR 场景适配
5. 美术：厚度图 / 噪声贴图代替部分程序噪声

## 6. 分支约定

- `main`：独立演示工程（历史形态）
- `addon`：仅包含插件化目录内容（可直接放到 `addons/mesh_volume_clouds/`）
