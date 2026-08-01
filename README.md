# Mesh Volume Clouds

面向 **移动端 / VR** 的网格假体积云 Godot 4.7 工程。  
从 Sunshine 全屏体积云方案切换而来：用多层造型网格 + 顶点动画 + Shader 模拟云感，帧率更可预期。

## 环境要求

- Godot **4.7**（Forward+ / Mobile）
- Windows / macOS / Linux 均可
- Android 导出可选（需 Android SDK）

## 快速开始

```bash
git clone <本仓库 URL>
# 用 Godot 4.7 打开项目根目录（含 project.godot）
# 主场景：demo/mesh_clouds_demo.tscn
# 按 F5 运行
```

操作：自动沿航点飞行；点击屏幕暂停/继续；右上角显示 FPS。

## 目录结构

```
mesh-volume-clouds/
├── project.godot
├── README.md
├── docs/
│   └── DEVELOPMENT.md          # 开发文档（架构、参数、路线图）
├── demo/
│   ├── mesh_clouds_demo.tscn   # 演示场景（浮空岛 + 云团 + 飞行相机）
│   ├── flythrough_camera.gd
│   └── mesh_clouds/
│       ├── mesh_cloud.gdshader
│       ├── mesh_cloud_cluster.gd
│       └── mesh_cloud_sun_sync.gd
└── build/                      # 本地导出产物（默认不提交 APK）
```

## 设计要点

| 目标 | 做法 |
|------|------|
| 高空可见、可俯视/穿云 | 真实 3D 网格，不是半球天空 |
| 移动端/VR 友好 | Mobile 渲染器；无全屏 raymarch |
| 云感 | 多层 puff + 顶点位移 + 软边/透光/银边 Shader |

更细的说明见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)。

## 许可证

工程内代码按项目需要自行约定；图标来自 Godot 默认资源风格。
