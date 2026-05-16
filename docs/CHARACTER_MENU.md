# 角色菜单与属性面板
[文档索引](README.md) | [Índice](README.es.md)

本文档描述**角色信息菜单**（character menu）及其中的**属性面板**（attributes panel）的架构与资源约定。

---

## 一、结构概览

| 组件 | 路径 | 职责 |
|------|------|------|
| **character_menu** | `Script/menu/characterInfo/character_menu.gd` | 角色菜单容器，切换「属性/技能」等标签页，调用 `attributes_panel.refresh_from_player()` |
| **attributes_panel** | `Script/menu/characterInfo/attr_panel/attributes_panel.gd` | 属性面板，展示角色名、职业、SYNC 等级、生命/攻防闪、经验条、基因抽象值等 |
| **场景** | `Scene/menu/characterInfoMenu/attr/attributes_panel.tscn` | 属性面板场景，作为 character_menu 的子实例 |

---

## 二、SYNC 等级与图标

### 2.1 SYNC 含义

- **SYNC-1～SYNC-5**：按等级区间表示同步层级；每 `LEVELS_PER_SYNC_TIER`（默认 5）级为一个区间。
- 到达区间末端（如 5、10、15 级）时可进行「突破」叙事。

### 2.2 图标资源

| 项目 | 说明 |
|------|------|
| **目录** | `素材/image/CharacterMenu/AttrPanel/SYNC/` |
| **命名** | `SyncLevel1.png`～`SyncLevel5.png`，对应 SYNC-1～SYNC-5 |
| **加载方式** | 脚本在 `_ready` 中 `_preload_sync_textures()` 一次性加载，按 `tier` 设置 `SyncIcon.texture` |
| **场景默认** | `attributes_panel.tscn` 中 `SyncIcon` 默认纹理为 `SyncLevel1.png`（编辑器预览用） |

### 2.3 相关常量与变量

- `SYNC_ICON_DIR`：SYNC 图标所在目录
- `_sync_textures`：预加载的 5 张 Texture2D 数组，索引 0 对应 SYNC-1
- `_apply_sync_icon(tier)`：按 `tier` 设置 `SyncIcon.texture`

---

## 三、属性面板数据来源

| 数据 | 来源 |
|------|------|
| 角色名、职业 | `UserManager.current_character_name`、`UserManager.current_character_class`、`GeneManager.character_class`；职业为空时默认 `Berserk Mutant`（FishMan 默认职业） |
| 等级、经验、生命、攻防闪 | `Player.player_stats`（Stats） |
| 基因抽象值 | `GeneManager.gene_points` |
| 职业图标 | `素材/image/CharacterMenu/AttrPanel/class/{character_class}.png` |

---

## 四、相关资源路径

| 类型 | 路径 |
|------|------|
| 职业图标 | `素材/image/CharacterMenu/AttrPanel/class/` |
| SYNC 图标 | `素材/image/CharacterMenu/AttrPanel/SYNC/SyncLevel1.png`～`SyncLevel5.png` |
| 属性图标 | `素材/image/CharacterMenu/AttrPanel/attr_icon/` |

---

## 五、与其它系统的关系

- **Stats**：`attributes_panel` 通过 `SkillManager.character.player_stats` 或 `CharacterDataManager.get_player().player_stats` 获取属性。
- **GeneManager**：监听 `genes_changed`，刷新抽象值与描述。
- **UserManager**：读取当前角色名与职业。
- **character_menu**：打开「属性」标签时调用 `attributes_panel.refresh_from_player()`。
