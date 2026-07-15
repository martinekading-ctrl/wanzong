# 《万宗》占位美术指南

当前内容是 0.5.0 Pre-Alpha 的可替换 placeholder，不是最终商业美术。

## 美术方向与调色板

- 方向：2D 中式修仙像素经营游戏，沉稳、高信息可读性。
- 深墨青 `#102b2d`、青玉 `#4fae9d`、克制古金 `#967a49`、深木 `#5c3f2b`、米白 `#eee5cb`。
- 五宗门分别使用青玉、青蓝银灰、赤铜丹红、暗红紫黑、米白土金。

## 可重复生成

运行 `python tools/art/generate_placeholder_art.py`。固定随机种子为 `20260715`；生成器离线运行，只清理 `assets/placeholder_art/` 与 `docs/art/contact_sheets/` 两个任务自有目录。运行 `python tools/art/generate_placeholder_art.py --verify-only` 可检查 manifest、尺寸和 Alpha。

## 文件与尺寸规则

- 文件名只使用小写英文、数字和下划线。
- 地形 tile 为 16×16，按最近邻显示；每类至少 3 个变体。
- 图标输出 24×24、32×32、48×48。
- 头像输出 256×256 与 64×64。
- 人物 sprite sheet 单帧 32×48，18 列 × 4 方向；列顺序为 idle 4、walk 4、work 4、cultivate 4、injured 2。
- 特效单帧 64×64、8 帧横排。
- UI 面板和按钮使用 8–12 px 安全边距；拉伸时由 Theme/StyleBox 的 content margin 管理。

## Theme 类型

按钮：`WZPrimaryButton`、`WZSecondaryButton`、`WZGhostButton`、`WZDangerButton`、`WZNavButton`、`WZNavButtonSelected`。

面板：`WZPanel`、`WZHUDPanel`、`WZDialogPanel`、`WZCardPanel`、`WZTooltipPanel`。

文字：`WZScreenTitle`、`WZSectionTitle`、`WZBody`、`WZMutedText`、`WZResourceText`、`WZSuccessText`、`WZDangerText`。

世界 HUD 继续保留 Task-0067 的 `WZWorld*` 类型和贴边布局。

## 替换正式素材

1. 保持文件尺寸、Alpha 和 sprite sheet 帧布局，替换同名 PNG。
2. 如尺寸或边距变化，更新 `assets/ui/wanzong_theme.tres`。
3. 更新 manifest 中对应记录，重新执行 Task-0068 测试。
4. 地形或自然物变化后，用事务式 WorldMapBaker 重新烘焙；不得更改地图逻辑坐标、宗门 ID 或资源 ID。

## 接入状态

- 已接入：主菜单背景、青玄宗综合页背景、战报背景、全局 Theme 类型、世界地图新 tile/自然物源、三个预览场景。
- 静态占位：人物头像/精灵、五宗门建筑、完整 UI 与图标库、特效和部分系统卡片。
- 保留真实逻辑：世界地图、五宗门、资源点、建设点、存档、经济、AI、战斗和外交。
- 后续正式替换：高差异度人物、精细建筑、动画细节、字体与最终场景构图。
