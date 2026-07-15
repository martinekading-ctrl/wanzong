# Task-0068.0 美术资产清单

本清单记录《万宗》0.5.0 Pre-Alpha 的可替换占位美术。逐文件尺寸、Alpha、sprite sheet 帧规格和替换路径以 `assets/placeholder_art/manifest/placeholder_art_manifest.json` 为准；下表按玩家功能分组，避免把 948 个生成文件重复抄写到文档。

| asset_id | 类型 | 用途 | 输出路径 | 目标尺寸 | 透明 | 九宫格 | sprite sheet | 场景接入 | 正式替换方式 |
|---|---|---|---|---|---|---|---|---|---|
| global_ui | 全局 UI | 面板、按钮五态、条、框、徽记 | `assets/placeholder_art/ui/**` | 16–192 px | 是 | 面板/按钮是 | 否 | Theme 与全部玩家页面 | 同名 PNG + Theme |
| main_menu | 主菜单 | 山水背景、标题区、设置与错误弹窗 | `assets/placeholder_art/scenes/main_menu/**` | 1920×1080 / 组件 | 混合 | 组件是 | 否 | `MainMenu.tscn` | 同名 PNG |
| world_map | 世界地图 | 23 类地形、11 类过渡、自然物和地标 | `assets/placeholder_art/world/**` | 16×16 / 48×64 / 96×96 | 混合 | 否 | 特效是 | TileSet、World、预览 | 同名 PNG 后重烘焙 |
| qingxuan_scene | 青玄宗主场景 | 山门背景与独立建筑 | `assets/placeholder_art/sects/backgrounds/**` | 1920×1080 | 否 | 否 | 否 | `PlayerSectOverview.tscn` | 同名背景 PNG |
| disciple_ui | 弟子系统 | 头像卡、人物名册与状态图标 | `characters/**`, `icons/status/**` | 64/256 / 32×48 | 是 | 否 | 是 | 青玄宗综合页与预览 | 同名 PNG/表 |
| building_ui | 建筑系统 | 建筑卡、建造栏、16 类建筑 | `sects/buildings/**`, `scenes/building/**` | 48–256 px | 是 | 卡片是 | 否 | 青玄宗综合页与预览 | 同名 PNG |
| diplomacy_ui | 外交系统 | 宗门卡、关系层、徽章与旗帜 | `scenes/diplomacy/**`, `sects/{emblems,banners}/**` | 64–256 px | 是 | 卡片是 | 否 | 青玄宗综合页与预览 | 同名 PNG |
| resource_ui | 资源系统 | 资源图标、资源条和节点 | `icons/resources/**`, `world/resource_nodes/**` | 24/32/48 px | 是 | 否 | 否 | HUD 与宗门页 | 同名 PNG |
| mission_ui | 任务系统 | 任务卡、奖励与条件条 | `scenes/mission/**` | 192×96 | 是 | 是 | 否 | 青玄宗综合页 | 同名 PNG |
| inventory_ui | 背包系统 | 物品格、品质框、物品图标 | `scenes/inventory/**`, `icons/resources/item_*.png` | 48–192 px | 是 | 部分 | 否 | 青玄宗综合页 | 同名 PNG |
| market_ui | 市场系统 | 商品卡、价格、买卖按钮 | `scenes/market/**` | 192×96 | 是 | 是 | 否 | 青玄宗综合页 | 同名 PNG |
| battle_ui | 战报系统 | 背景、单位卡、战报框和条 | `scenes/battle/**` | 1920×1080 / 组件 | 混合 | 组件是 | 否 | `BattleReport.tscn` | 同名 PNG |
| save_load_ui | 存读档 | 存档格、损坏态、确认弹窗 | `scenes/save_load/**` | 192×96 | 是 | 是 | 否 | 主菜单与青玄宗综合页 | 同名 PNG |
| settings_ui | 设置 | 音量、切换、下拉、关闭 | `scenes/save_load/settings_*.png` 等 | 192×96 | 是 | 是 | 否 | 主菜单设置弹窗 | 同名 PNG |
| tutorial_ui | 教程 | 遮罩、高亮、箭头、步骤面板 | `scenes/save_load/tutorial_*.png` | 192–256 px | 是 | 部分 | 否 | `TutorialOverlay.tscn` | 同名 PNG |
| event_ui | 事件弹窗 | 选项、结果、警告、成功、Toast | `scenes/save_load/*dialog*.png`, `toast.png` | 192×96 | 是 | 是 | 否 | 青玄宗综合页 | 同名 PNG |
| portraits | 人物头像 | 五宗门宗主、长老、弟子和 NPC | `characters/portraits/**` | 256×256 / 64×64 | 是 | 否 | 否 | 预览；综合页保留真实数据 | 同名头像 PNG |
| map_sprites | 人物地图精灵 | 四方向角色基准帧 | `characters/map_sprites/**` | 32×48 | 是 | 否 | 否 | 预览 | 同名 PNG |
| character_sheets | 人物动画 | idle/walk/work/cultivate/injured，四方向 | `characters/sprite_sheets/**` | 32×48 帧 | 是 | 否 | 是 | 预览 / SpriteFrames | 同名 sprite sheet |
| sect_buildings | 宗门建筑 | 16 类建筑地图、卡片、锁定和选中态 | `sects/buildings/**` | 48/128/144/256 px | 是 | 否 | 否 | 青玄宗与预览 | 同名 PNG |
| world_landmarks | 世界建筑 | 五宗总部、村镇、塔、桥、矿与秘境 | `world/landmarks/**` | 96/128 px | 是 | 否 | 否 | 地图与预览 | 同名 PNG |
| terrain_tiles | 地形 TileSet | 23 类地形、每类 3 变体 | `world/terrain/**` | 16×16 | 否 | 否 | 否 | 世界烘焙 TileSet | 替换后重烘焙 |
| world_nature | 自然装饰物 | 树、竹、岩、花、云、雾、瀑布 | `world/nature/**` | 48×64 | 是 | 否 | 否 | 世界 MultiMesh 与预览 | 同名 PNG 后重烘焙 |
| resource_nodes | 资源点 | 矿、药田、灵脉、码头等地标 | `world/landmarks/**`, `icons/resources/**` | 48–96 px | 是 | 否 | 否 | 世界真实资源节点 | 同名 PNG |
| effects | 特效 | 12 类 8 帧像素特效 | `world/effects/**` | 64×64 帧 | 是 | 否 | 是 | 预览 / SpriteFrames | 同名 sprite sheet |
| status_icons | 状态图标 | 健康、受伤、修炼、工作、关系等 | `icons/status/**` | 24/32/48 px | 是 | 否 | 否 | 弟子/外交页面 | 同名 PNG |
| missing_assets | 缺失素材 | 正式字体、最终角色差异、最终动画与商业级场景 | 无 | 待定 | 待定 | 待定 | 待定 | 未接入 | 用户后期正式制作 |
| retained_assets | 已存在可保留素材 | 原世界逻辑、旧像素宗门/资源图、烘焙结构 | `assets/pixel/**`, `assets/generated/**` | 原规格 | 混合 | 否 | 否 | 保留逻辑兼容 | 逐项迁移，不直接删除 |
| task_0068_generated | 本轮生成素材 | 全部程序化占位素材及联系表 | `assets/placeholder_art/**`, `docs/art/contact_sheets/**` | manifest 记录 | 混合 | 混合 | 混合 | 已接入核心页面/预览 | 通过 manifest 定位替换 |

## 当前玩家可见入口

- 主菜单 → 世界地图 → 青玄宗综合页。
- 青玄宗综合页承载弟子、建筑、资源、历史、存读档、任务、外交、背包与市场真实数据/逻辑。
- 战报为独立页面，教程为叠加层。
- 三个 Gallery 仅用于美术验收，不是主场景，也不提供虚构玩法数据。
