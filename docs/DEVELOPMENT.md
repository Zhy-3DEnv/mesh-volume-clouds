# 网格体积云 — 开发文档

## 1. 背景与目标

### 1.1 已停用方向

- **Sunshine Clouds 2**：真体积 raymarch，穿云/俯视能力强，但 Adreno 上对着云帧率偏低，画质与性能难兼顾。
- **Clayjohn 半球天空体积**：性能好，但不适合高空俯视与穿云。

### 1.2 当前方向

**网格假体积云（Mesh Fake Volume Clouds）**

- 每朵云 = 多个扁球体 / 后续可换成云造型网格
- Shader：软边 alpha、顶亮底灰、透光、银边、噪声侵蚀轮廓
- 顶点：FBM + cellular 位移，缓慢翻滚
- 目标平台：Android（Forward Mobile）、后续 VR

手机实测（初期原型）：对着云飞行约 **60 FPS**（Adreno 740，Mobile 渲染器）。

---

## 2. 架构

```
MeshCloudsDemo (Node3D + mesh_cloud_sun_sync.gd)
├── WorldEnvironment / DirectionalLight3D / Ground
├── FloatingIslands          # 场景参照几何
├── Clouds
│   ├── Cloud1..Cloud5       # MeshCloudCluster
│   │     └── Puff_0..N      # SphereMesh + 共享 ShaderMaterial
└── Camera3D                 # flythrough_camera.gd
```

### 核心脚本

| 文件 | 作用 |
|------|------|
| `mesh_cloud_cluster.gd` | 按 seed 生成多 puff；导出半径/扁平/段数等 |
| `mesh_cloud.gdshader` | 外观与动画 |
| `mesh_cloud_sun_sync.gd` | 每帧把平行光方向写入云材质 |
| `flythrough_camera.gd` | 航点循环飞行 + FPS HUD |

群组：`mesh_cloud_cluster`（用于太阳方向同步）。

---

## 3. Shader 参数速查

材质在场景 `ShaderMaterial_cloud` 或脚本默认值中配置。

### Appearance

| 参数 | 含义 |
|------|------|
| `albedo` | 云主体色 / alpha |
| `underside_color` | 底部偏灰蓝 |
| `density` | 整体不透明度强度 |
| `soft_edge` | 视角软边（越大边缘越虚） |
| `edge_erosion` | 噪声咬边强度 |
| `fluff` | 蓬松/团块感 |
| `center_fill` | 中心填充下限，防完全镂空 |

### Lighting

| 参数 | 含义 |
|------|------|
| `light_wrap` | 包裹光照 |
| `translucency` | 逆光透光 |
| `silver_lining` | 轮廓银边 |
| `ambient_boost` | 环境提亮 |
| `sun_direction` | 由 sun_sync 自动更新 |

### Animation

| 参数 | 含义 |
|------|------|
| `displacement_amp` | 顶点位移幅度 |
| `displacement_scale` | 位移噪声尺度 |
| `displacement_speed` | 动画速度 |
| `secondary_amp` | 第二层噪声混合 |
| `detail_scale` | 片元细节噪声尺度 |

---

## 4. 云团节点参数（MeshCloudCluster）

| 导出 | 含义 |
|------|------|
| `puff_count` | 子球体数量（1–12） |
| `base_radius` | 基础尺度（世界单位，演示约 1000） |
| `spread` | 水平散布 |
| `vertical_squash` | 垂直压扁（<1 更像云层） |
| `mesh_segments` | 球体细分（移动端建议 12–16） |
| `seed` | 随机种子，改外形 |
| `cloud_material` | 共享材质（利于合批） |

---

## 5. 本地开发流程

1. Godot 4.7 打开本仓库根目录。
2. 运行主场景，观察 FPS 与穿云观感。
3. 调云：选中 `Clouds/Cloud*` 改导出；调材质：改 `ShaderMaterial_cloud`。
4. 改 Shader 后保存，编辑器会热重载；真机需重新导出。

### Android 导出（可选）

1. 编辑器配置 Android 导出模板与 SDK。
2. 导出 Debug APK 到 `build/`。
3. 若签名失败，可用 build-tools 35 `apksigner` 重签（与原 test-01 流程相同）。

建议 Android 使用项目中的：

```
renderer/rendering_method.mobile="mobile"
```

---

## 6. 性能注意

- 半透明 overdraw 是主要成本：控制 puff 数量与屏幕覆盖。
- 关闭云阴影（脚本已 `SHADOW_CASTING_SETTING_OFF`）。
- 共享同一 `ShaderMaterial` 便于合批。
- 片元里避免过重 Worley；cellular 目前主要在顶点阶段。
- VR：注意双眼填充与半透明排序，优先少层、远距降段数。

---

## 7. 建议路线图

1. **造型**：用真正的云状网格（Blender）替换 SphereMesh。
2. **LOD**：远距减少 puff / 段数，或换不透明近似。
3. **近景**：穿云时加一层轻雾/粒子壳。
4. **VR**：OpenXR 场景适配、减少全屏后处理。
5. **美术向**：厚度图 / 噪声贴图代替部分程序噪声。

---

## 8. 与旧工程关系

本仓库从 `GodotProject/test-01` 中抽出网格云相关内容，**不依赖** SunshineClouds2 / Clayjohn / godot_ai 插件，可独立打开与提交。

演示场景尺度（高度约 7000、岛屿间距数千单位）与旧浮空岛 demo 对齐，便于对比观感。

---

## 9. 提交约定（建议）

- 功能：`feat: ...`
- 修复：`fix: ...`
- 文档：`docs: ...`
- 勿提交 `.godot/`、大型 APK、密钥。
