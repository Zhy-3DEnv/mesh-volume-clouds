# 云造型网格（Houdini）

| 文件 | 用途 |
|------|------|
| `cloud_shape_a.glb` / `cloud_shape_a_lod.glb` | 直接拖给 `MeshCloudCluster.cloud_mesh` / `cloud_mesh_lod` |
| `*.vnbin` | 可选旁路法线（与同名 GLB 一起导出）；有则自动修复 Godot 导入坏掉的法线 |

**用法：** 直接引用 `.glb` 即可，不必再单独抽 `.mesh`。

说明：Godot 把 GLB 当场景导入时经常弄坏顶点法线。`MeshCloudCluster` 在解析 GLB 时会：
1. 若存在同名 `.vnbin` → 按顶点位置写回 Houdini 法线  
2. 否则 → 按拓扑重算平滑法线  

## 重新导出

1. Houdini 导出更新 `.glb`
2. 同步生成 `.vnbin`（推荐，保留 Houdini 原始法线）：
   ```
   python 旁路脚本 / 或让 AI 从 GLB 导出 vnbin
   ```
   当前仓库已带 `cloud_shape_a.vnbin` / `cloud_shape_a_lod.vnbin`。
