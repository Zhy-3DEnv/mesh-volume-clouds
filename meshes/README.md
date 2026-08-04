# 云造型网格（Houdini）

| 文件 | 来源 | 约三角数 | 用途 |
|------|------|----------|------|
| `cloud_shape_a.obj` | `/obj/geo1/normal1` | ~10k | 近景 / 默认 |
| `cloud_shape_a_lod.obj` | `/obj/geo1/normal_lod`（polyreduce + Normal） | ~1k | 远景预留 |

在 `MeshCloudCluster` 上指定 `cloud_mesh`（近）/ `cloud_mesh_lod`（远）。  
运行时：`lod_enabled` 且两份网格都有时，相机距离 > `lod_distance` 用低模，靠近时（含 `lod_hysteresis` 滞后）切回高模。尺度以高模 AABB 归一化，切换时尺寸不跳。

重新导出（Houdini）：对 `/out/mcp_export_hi`、`/out/mcp_export_lod` 点 Execute，或让 AI 走 ROP 导出流程。
