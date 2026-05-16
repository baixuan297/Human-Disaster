# 工程问题与修复记录（Issue Log）
[← 文档索引](../README.md#文档索引)

本文件汇总本项目开发过程中出现的问题、原因与解决方案，便于复盘与 onboarding。  
**维护约定**：之后每解决一类问题，请在本文件**按日期追加**一条（或一小节），包含：**现象** → **原因** → **涉及路径** → **处理要点**。

---

## 0. 范围与完整性说明（重要）

| 说明 | 内容 |
|------|------|
| **是否「全部」** | **否。** 仓库曾在多轮 Cursor 会话中修改；本文件**不可能**在无人工逐条对照 Git 历史的前提下声称已穷举所有问题。 |
| **正文详述部分** | **§1～§5** 主要对应会话 [GlobalMessage与经验等](768101d3-ea86-4c21-b41e-3348a85a6fd0)，该段在台账内相对完整。 |
| **§7 摘要** | 其余 UUID 会话仅作**索引级摘要**（见下）；若需细节，请打开本地 `agent-transcripts/<UUID>/` 内 `.jsonl` 或对照当时提交。 |
| **§8 代码审计** | **2026-03-30** 起：对仓库内 `.gd` / `project.godot` / 关键 `.tscn` 的**静态扫描**，记录冗余与遗留；**非**运行时性能分析，亦**未**声称穷举每一行注释。 |
| **§4.2 后端对齐** | **2026-03-30**：`game.character_stats` / 背包 / 技能 / 基因 / 场景状态 与 `PSQL_DH` 模型、路由、Godot 调用**字段级对照**（见下）。 |
| **§9 后续 TODO** | **滚动清单**：文档路径校正、代码清理、后端接入等待办；完成项请打勾并在 **§6** 追加一条修复记录（含日期）。 |
| **建议** | 重大修复合并进 `main` 时，在 **§6 模板** 追加一行并写**提交哈希或日期**，台账才易与代码一一对应。 |

---

## 归档来源（多会话）

| 会话（内部索引） | 大致主题 |
|------------------|----------|
| [GlobalMessage与经验等](768101d3-ea86-4c21-b41e-3348a85a6fd0) | GBMssage 遮挡/重构/注释、`display_time`、`Stats` 经验封顶与敌人固定等级、`player_stats`、后端 stats 对齐、本 md 初稿 |
| [审查 autoload 与武器相机等](10b3514a-c3c6-4bea-a467-52408dea4d2e) | 全项目审查、SignalBus/SaveManager/UserManager/SceneManager、GlobalMessage 初版底部 Toast、**WeaponManager 误作 autoload**、CameraRigFP、interactray 导出、Weapon_manager 挂角色根、第三人称相机与背包 UI 等 |
| [Hazard 毒池与 UI 等](3c4814c1-5123-4603-b13e-5346b6b8bac3) | 场景伤害（毒池）、生命 UI 不刷新、`Hazard` 类型 enum、后端抗性对齐、仅资源驱动 hazard、Fishman 预览、测试体系/GDD 等讨论 |
| [后端融合与 APIManager 等](47a2fae7-d7f4-4c3a-93a7-a63b300ca111) | SQL 融合、FastAPI 与 Godot API、首次登录默认角色、`game_data` ID、UserManager 服务端优先登录、Skill/BaseEnemy 等脚本合并 |

本地 Cursor 会话记录路径因安装与用户目录而异，一般在「当前工作区」对应的 Cursor 项目目录下 `agent-transcripts/<UUID>/*.jsonl`，勿在文档或脚本中写死磁盘绝对路径。

---

## 1. GlobalMessage（autoload：`GBMssage`）

### 1.1 底部 Toast 遮挡下层 UI（无法点击输入框等）

| 项目 | 说明 |
|------|------|
| **现象** | 全局消息在屏幕下方显示后，同区域背包分类栏、LineEdit、按钮等无法接收鼠标/触摸。 |
| **原因** | Godot 中 **`MOUSE_FILTER_IGNORE` 不会被子节点继承**。父节点 `ToastBar`/`ToastDock` 设为忽略后，子节点 `CenterContainer`、`PanelContainer` 等仍为默认 **`MOUSE_FILTER_STOP`**，占据底部整条命中区域，拦截输入。 |
| **处理** | 在 `_ready()` 中对 Toast 根节点子树执行 `propagate_call("set_mouse_filter", MOUSE_FILTER_IGNORE)`，整树穿透。若将来需要「点击关闭」，仅对可点控件单独设为 `STOP`。 |
| **文件** | `autoload/GlobalMessage/GlobalMessage.gd`（现为 `_toast_ignore_input_recursive`） |

### 1.2 样式与代码结构臃肿

| 项目 | 说明 |
|------|------|
| **现象** | 每次 `show_message` 新建 `StyleBoxFlat`；场景节点偏多。 |
| **处理** | 预缓存四类 `StyleBoxFlat`；内边距并入 `StyleBoxFlat.content_margin`，去掉多余 `MarginContainer`；节点重命名为 `ToastDock` / `Center` / `ToastCard` 等；逻辑拆分为 `_run_toast_tween`、`_sync_card_pivot`、样式构建函数。 |
| **对外 API** | 仍为 `GBMssage.show_message(text, type)`，调用方无需改。 |
| **文件** | `GlobalMessage.gd`、`GlobalMessage.tscn` |

### 1.3 `display_time` 调很大仍「一闪就没」

| 项目 | 说明 |
|------|------|
| **现象** | 将 `display_time` 设为 100 秒，Toast 仍很快消失。 |
| **原因** | **`Tween.chain().tween_interval(display_time)`** 与前后 **`set_parallel(true)`** 链式组合在部分 Godot 版本下会出现**间隔几乎不生效**的情况。 |
| **处理** | 淡入仍用 `Tween`；**完全显示后的停留**改为子节点 **`Timer`**（`wait_time = display_time`）。新消息时 `stop()` 旧计时器。`GlobalMessage` 设 **`process_mode = PROCESS_MODE_ALWAYS`**，避免暂停菜单下计时不走（可按产品改回 `INHERIT`）。`display_time == 0` 时用极小 `wait_time` 再淡出，避免 0 秒 Timer 异常。 |
| **文件** | `autoload/GlobalMessage/GlobalMessage.gd` |

### 1.4 文档与注释

| 项目 | 说明 |
|------|------|
| **说明** | `GlobalMessage.gd` 已补充文件头、场景树、类型、鼠标策略、各函数说明。 |
| **限制** | `.tscn` 文本格式**不能**写 `#`/`//` 注释，结构说明写在脚本头部。 |

---

## 2. Stats / 经验与等级（玩家）

### 2.1 经验与等级机制不完整、UI 公式重复

| 项目 | 说明 |
|------|------|
| **现象** | 缺等级上限与经验封顶；属性面板与 `Stats` 各写一套分段公式，易漂移。 |
| **处理** | 增加 `max_level`（默认 30）、总经验封顶、`get_level_experience_segment()` 单源供给经验条；`gain_experience` 返回实际增加值；`character_level_up` **仅在等级上升**时发射；`load_from_dict` 用 `_mute_level_up_signal` 避免登录误弹升级。 |
| **文件** | `resource/stats/stats.gd`、`attributes_panel.gd`、`Player.gd`（连接 `GBMssage`）、`player_stats.tres`、`docs/EXPERIENCE_SYSTEM.md` |

---

## 3. 敌人等级 vs 玩家经验（Stats 双模式）

### 3.1 敌人只需固定等级、不获得经验

| 项目 | 说明 |
|------|------|
| **需求** | 敌人只配置「当前等级」；不攒经验；玩家击杀仍给**玩家**加经验。 |
| **处理** | `Stats` 增加 `level_derived_from_experience`（玩家 `true`，敌人 `false`）与 `fixed_combat_level`。敌人模式下 `gain_experience` 返回 0；`experience` 保持 0；`load_from_dict` 不写入经验；`get_level_experience_segment()` 对敌人返回占位。 |
| **资源** | `enemy_stats.tres`、`trainingBot_stats.tres`；玩家 `player_stats.tres` 显式 `level_derived_from_experience = true`。 |
| **文件** | `resource/stats/stats.gd`、`Script/enemy/BaseEnemy.gd`（注释说明） |

### 3.2 变量命名：snake_case 与完整词；`playerStats` → `player_stats`

| 项目 | 说明 |
|------|------|
| **处理** | `stats.gd` 内局部变量改为完整 snake_case；导出 **`Player.player_stats`**，全项目 `get("player_stats")` 与文档同步。 |
| **文件** | `Player.gd`、`Fish_Man.tscn`、`CharacterDataManager.gd`、`WeaponManager.gd`、`Skill.gd`、`Bullet.gd`、`attributes_panel.gd`、`BaseEnemy.gd` 等；若干 `docs/*.md`。 |

---

## 4. 后端数据库与 API 对齐（角色属性）

### 4.1 客户端存档字段与 FastAPI / PostgreSQL 一致

| 项目 | 说明 |
|------|------|
| **结论** | `Stats.save_to_dict()` 与 `CharacterStatsSaveRequest` / `CharacterStatsResponse` / `game.character_stats` 一致；**等级不单独入库**，仅 **`experience`**，等级由客户端公式 + `max_level` 推导。 |
| **基线** | `experience`、抗性、`loadout`、`scene_state` 等字段须在游戏 API 使用的 PostgreSQL 中存在；由服务端部署初始化，客户端按 [APIManager.md](APIManager.md) 契约读写。 |
| **注意** | `game.character_stats` 列与枚举与 `models.py` 一致；不再维护 `migrations/*.sql` 分文件。 |
| **未使用** | `game.character_progress`（含 level/experience）当前 **未** 在 `main.py` / ORM 中接入，与现 Godot 存档链路无关。 |

### 4.2 全链路对齐核对（数据库 ↔ ORM ↔ API ↔ Godot，2026-03-30）

以下为**静态对照**结论：游戏 API 数据库中的 `game.character_stats` 等表结构须与 `APIManager` / `CharacterDataManager` 使用的 JSON 字段一致。

#### `game.character_stats`（属性 + loadout + scene_state JSON）

| 列 / JSON 字段 | SQLAlchemy `CharacterStats` | Pydantic `CharacterStatsSaveRequest` / `CharacterStatsResponse` | Godot |
|----------------|----------------------------|------------------------------------------------------------------|--------|
| `max_health` … `evasion` | ✓ | ✓ | `Stats.save_to_dict()` / `load_from_dict()` 键名一致 |
| `experience` | ✓（基线 `DesastreHuman.sql`） | ✓ | `Stats.experience`；**等级不入库**，客户端由公式 + `max_level` 推导（与 §2 一致） |
| `fire_resistance` … `other_resistance` | ✓（基线，对应 `Hazard.HazardType` 0～3） | ✓ | `Stats.fire_resistance` 等，`load_from_dict` 已 `clampf` 0～1 |
| `loadout`（JSONB） | ✓（基线） | Save 可选；GET stats 返回 | `CharacterDataManager` 合并 `WeaponManager.get_serializable_loadout()` 后 POST |
| `scene_state`（JSONB） | ✓（基线） | 仅 **SaveRequest**；**GET `/stats` 响应体不含** `scene_state` | 登录后 **`load_scene_state`** 拉取；`save_to_api` 将 `scene_state` **合并进同一次** `save_stats` POST，避免覆盖 loadout（与 `main.py` 注释一致） |

#### 其他角色相关接口

| 领域 | 后端 | 客户端 | 说明 |
|------|------|--------|------|
| 背包 | `InventorySaveRequest.slots`：每槽 `{id, qty}` 或空 | `InventoryManager.get_serializable_inventory()` | `main.py` 中 `CLIENT_INVENTORY_SLOT_COUNT = 60` 与 `InventoryManager.max_slots` 一致 |
| 技能 | `SkillsSaveRequest`：`SkillState` **仅** `level` | `SkillManager.save_skills_data()` 另含 `cooldown_remaining` | Pydantic 会**忽略**多余字段；读档时 `CharacterDataManager` 将 `cooldown_remaining` 置 **0**——**服务端不持久化冷却**，属当前设计 |
| 基因 | `GenesStateSaveRequest`：`gene_id, current_level, is_active, points_spent` | `GeneManager.get_serializable_state()` / `from_dict` | 字段与 `game.character_genes` 一致 |
| 场景状态（独立路由） | `SceneStateResponse` / `SceneStateSaveRequest`：`scene_path, position, rotation_y, collected_pickables` | `ApiManager.save_scene_state` / `load_scene_state` | 与 `CharacterDataManager._scene_state_snapshot` 一致；合并存档时 `collected_pickables` 一并写入 `stats.scene_state` |

#### 部署与验证提醒

| 项 | 说明 |
|----|------|
| **基线** | 新环境必须先执行 `DesastreHuman.sql`（或等价结构）再启动 FastAPI，否则缺列会导致读写失败。 |
| **联调** | 使用 `test/api_test.tscn` / `test/api_test.gd` 与 `docs/APIManager.md` 中的路径对照；`ApiManager.API_BASE_URL` 需指向实际后端。 |

---

## 5. 调用兼容性检查（GlobalMessage 重构后）

| 项目 | 说明 |
|------|------|
| **结论** | 登录/注册等仅依赖 `GBMssage.show_message`，无旧节点路径、无已删除的公共 `messageLabel` 引用。 |
| **注意** | `addons/xuanBag/scripts/sample.gd` 内 `show_message` 为**本地函数**，与 autoload 无关。 |

---

## 6. 后续记录模板（复制后填写）

```markdown
### YYYY-MM-DD — 简短标题

| 项目 | 说明 |
|------|------|
| **现象** | |
| **原因** | |
| **处理** | |
| **文件** | `path/...` |
```

---

## 7. 其他归档会话中的问题与处理（摘要，非穷举）

以下为 **§0** 所列其他 UUID 中出现过的典型问题，**仅作索引**；具体改动的文件与 diff 以仓库现状与对话记录为准。

### 7.1 审查、SignalBus、SaveManager、GlobalMessage 初版样式（`10b3514a…`）

| 主题 | 现象 / 问题 | 处理方向（摘要） |
|------|-------------|------------------|
| SignalBus | 信号全被注释 → autoload 形同空壳；后按需求恢复为**占位**（不启用信号） | 与 `AUTOLOAD_AND_UI.md` 说明一致 |
| SaveManager | `while get_line` 多行 JSON 不可靠；写文件未校验打开结果 | 整文件读写 + 校验 |
| UserManager | `login_local` 缺键时崩溃 | `has` 检查 |
| SceneManager | 资源缺失时空引用 | `load` / `PackedScene` 校验 |
| GlobalMessage | 中央裸 Label → 底部 Toast + StyleBoxFlat + 动效 | 后续在 `768101d3…` 会话中又做了一轮架构优化（§1.2） |

### 7.2 WeaponManager autoload 与相机子场景（`10b3514a…`）

| 主题 | 现象 / 问题 | 处理方向（摘要） |
|------|-------------|------------------|
| WeaponManager | **同时**注册为 **autoload** 且挂在 `FPCamera` 下 → autoload 实例父节点为 **Window**，`_bind_runtime_nodes` 报错 | 从 `project.godot` **移除** WeaponManager autoload；`_ready` 父节点非 `Camera3D` 时提前 return / 警告 |
| interactray | 子场景 `CameraRigFP` 内 `@export var player` 未赋值 → `add_exception` 异常 | 运行时绑定或场景里补引用 |
| 架构 | Weapon_manager 迁至**角色根**子节点 | 更新 `Player` / `WeaponManager` 查找逻辑（以当前场景为准） |

### 7.3 第三人称相机与背包 UI（`10b3514a…`）

| 主题 | 说明 |
|------|------|
| 第三人称控制 | 曾报「第三人称控制有问题」，需结合 `CameraController` / `MovementComponent` 当时版本排查 |
| 背包 Bottom | 曾分析 Inventory UI 底部按钮信号、遮挡与 autoload 全屏层等（与 §1.1 同类：命中测试与层级） |

### 7.4 场景 Hazard、毒池、生命 UI（`3c4814c1…`）

| 主题 | 现象 / 问题 | 处理方向（摘要） |
|------|-------------|------------------|
| poison_pool | 环境伤害不扣血 | 统一走 `Stats` / `AttackData` / `Hazard` 链路 |
| 生命 UI | 受伤后 UI 不更新 | 连接 `health_changed` 或中继 `Player` 信号 |
| Hazard | 扩展类型 enum（火/毒/荆棘/其他） | `hazard.gd` + 调用点 + 后端抗性字段对齐 |
| 配置 | 去除无资源时的 export 兜底 | 强制 `hazard_data`，缺失则 `push_warning` |

### 7.5 后端、登录流、game_data（`47a2fae7…`）

| 主题 | 说明 |
|------|------|
| 库表与 FastAPI | SQL 融合、`models.py` / `schemas.py` / `main.py` 与 Godot `APIManager` 对齐 |
| 首次登录 | 自动创建默认角色、职业与剧情设定 |
| game_data | `items.json` / `skills.json` / `enemies.json` 等 ID 数字化规则 |
| UserManager | 以**服务端**数据为准的登录与角色加载 |

---

## 8. 代码冗余与遗留（据当前仓库静态扫描，2026-03-30）

以下条目在**删除或合并代码前**，建议在 Godot 编辑器与全局文本搜索中再确认引用（`.tscn` `ext_resource`、`preload`、autoload 名）。

### 8.1 可归类为「死代码 / 重复实现」

| 项目 | 说明 | 路径 |
|------|------|------|
| **遗留 view_model 脚本** | `Script/gun/view_model.gd` 与 `WeaponViewModel.gd` 同为枪模晃动（`lerp` + `sway`），且内含大段已注释的 mp7/pistol 分支。**当前** `Scene/gunshoot/view_model.tscn` 的脚本引用为 `WeaponViewModel.gd`，工程内无 `.tscn` 再指向 `view_model.gd`（仅个别文档仍口头提及该文件名）。 | `Script/gun/view_model.gd`；对照 `Scene/gunshoot/view_model.tscn` |
| **SignalBus 占位 autoload** | `SignalBus.gd` 几乎全部内容为**注释掉**的信号定义；`project.godot` 仍注册为 autoload；全项目 `.gd` 中**无**对 `SignalBus` 标识符的引用。功能上等价于「空壳单例」，长期占用 autoload 槽位。 | `autoload/SignalBus.gd`、`project.godot`；说明亦见 `docs/AUTOLOAD_AND_UI.md` §4 |
| **联机脚手架** | `Script/Multiplayer/Login.gd`、`find_match.gd`、`user_ready_screen.gd` 等保留大块注释掉的 Nakama/旧流程，可读性差且易与主线 `login_scene.gd` + `UserManager` / `ApiManager` 混淆。 | `Script/Multiplayer/*.gd` |

### 8.2 轻度冗余 / 可后续整理（非错误）

| 项目 | 说明 | 路径 |
|------|------|------|
| **SettingSignal 的 emit_* 封装** | 每个 `emit_*` 仅转发 `.emit()`，属风格层薄封装；可保留（调用方统一）或改为直接 `SettingSignal.xxx.emit(...)`。 | `autoload/SettingSignal.gd` |
| **登录场景未用节点引用** | `login_scene.gd` 声明 `@onready var message_label`，实际提示均走 `GBMssage.show_message`，该 Label 在脚本中**未被读写**（若场景中仍占位，可考虑删节点或接本地调试）。 | `Script/menu/loginScene/login_scene.gd` |
| **分散的注释块** | `Bullet.gd`、`SceneManager.gd`、`skill_button.gd`、`pausa.gd`、`world.gd` 等存在整段注释函数，体量小于 Multiplayer 目录但同样增加噪音。 | 各文件内 `#func …` 区块 |
| **敌人受击调试输出** | `BaseEnemy._on_health_changed` 等处的 `print` 利于开发期排查，发行版可关或改日志级别。 | `Script/enemy/BaseEnemy.gd` |

### 8.3 已缓解、无需再算「公式双写」的问题

| 项目 | 说明 |
|------|------|
| **经验条与等级段** | 属性面板通过 `stats.get_level_experience_segment()` 取单源数据，与 **§2** 描述一致；若再出现 UI 与 `Stats` 不一致，优先查是否绕过该 API。 |
| **全局提示 vs 背包 sample** | `addons/xuanBag/scripts/sample.gd` 的 `show_message` 为**本地 `print` 封装**，与 autoload `GBMssage` 无关，**不算**重复实现全局 Toast；见 **§5**。 |

### 8.4 文档与路径漂移（便于对账）

| 项目 | 说明 |
|------|------|
| **WeaponViewModel 等路径** | 运行时脚本为 `res://Script/gun/WeaponViewModel.gd`（`class_name WeaponViewModel`）。**2026-03-30** 已校正：`CHARACTER_AND_WEAPON_OVERVIEW.md`（BaseWeapon / WeaponViewModel / §2.5）、`WEAPON_SYSTEM.md`（WeaponAudioData / AudioPool）、`INVENTORY.md`（InteractionComponent）。若新增文档请避免再写 `test/*.gd` 旧路径（`test/api_test.gd` 等**确实在** `test/` 下的除外）。 |

---

## 9. 文档与模块说明：已同步项 & 后续 TODO（滚动）

本节说明：**哪些模块文档已与当前代码对齐**，以及**接下来建议谁来做、更新哪里**。完成某项后请在此打勾 `[x]`，并用 **§6 模板** 追加一条简短记录（日期 + 文件）。  
部署与联调待办由作者在个人笔记中单独维护；本节 §9 可与其对照勾选。

### 9.1 已确认更新或对齐的文档（相对本仓库代码）

| 文档 | 状态 |
|------|------|
| `PROJECT_ISSUES_AND_FIXES.md` | **§8** 代码冗余扫描；**§9** 本待办清单。 |
| `README.md` | 索引中已加入本台账入口（综合文档表）。 |
| `CHARACTER_AND_WEAPON_OVERVIEW.md` | 武器核心类路径已改为 `Script/gun/*`；**view_model.gd** 标注为遗留并指向 §8.1。 |
| `WEAPON_SYSTEM.md` | §6 关键文件表中 WeaponAudioData / AudioPool 路径已与仓库一致。 |
| `APIManager.md` | §5 中 `scene_state` 行已补充 `collected_pickables`（与 `SceneStateResponse` 一致）。 |
| **§4.2** | 后端 `PSQL_DH` 与 Godot 属性/背包/技能/基因/场景状态**对齐结论**（2026-03-30）。 |
| `INVENTORY.md` | InteractionComponent 路径已改为 `Script/player/InteractionComponent.gd`。 |
| `AUTOLOAD_AND_UI.md` / `EXPERIENCE_SYSTEM.md` / `DAMAGE_SYSTEM.md` / `CharacterDataManager.md` / `APIManager.md` 等 | 与 **§1～§5、§7** 描述一致；**未**在本次逐字重审全文，若大改 autoload 或 API 请回头对照更新。 |

### 9.2 文档侧 TODO（建议下次改文档时处理）

- [ ] 全库 `docs/**/*.md` 再搜一遍 `test/`：除 `test/api_test.gd`、`test/unit/` 等**真实位于 test 目录**的引用外，一律改为实际 `Script/`、`resource/`、`autoload/` 路径。
- [ ] 若启用后端 `game.character_progress` 或与 §4「未使用」不一致，更新 **§4**、**§4.2**、`APIManager.md`、`CharacterDataManager.md` 与迁移说明。
- [ ] 新环境部署后确认游戏 API 库表与客户端存档字段一致，并在 §6 记录环境/日期（与 §4.2 部署提醒一致）。
- [ ] 第三人称相机 / 背包遮挡若仍有产品级问题，在 **§7.3** 或 `PLAYER_CAMERA_AND_MOVEMENT.md` 补「复现步骤 + 当前结论」。
- [ ] 联机（Nakama）若重新立项，为 `Script/Multiplayer/` 单独写一页「现状 vs 废弃」以免与 `login_scene.gd` 混淆。

### 9.3 代码与工程清理 TODO（对应 §8）

- [ ] 全局确认无引用后 **删除或移入 `archive/`**：`Script/gun/view_model.gd`（冗余于 `WeaponViewModel.gd`）。
- [ ] **SignalBus**：要么取消 autoload 并删/合并文件，要么取消注释并接入一两条真实信号 + 在 `AUTOLOAD_AND_UI.md` 更新状态。
- [ ] `login_scene.gd`：移除未使用的 `message_label` 或改为与 `GBMssage` 二选一的明确策略（场景 `.tscn` 同步）。
- [ ] `Script/Multiplayer/*.gd`：删除注释块或移到 `docs/` 设计片段，减少与主线登录混读成本。
- [ ] `BaseEnemy.gd`：发行前将调试 `print` 改为 `print_verbose` / 日志宏或配置开关。

### 9.4 游戏系统文档维护约定（给后续贡献者）

| 约定 | 说明 |
|------|------|
| **单点事实** | 经验公式以 `resource/stats/stats.gd` + `EXPERIENCE_SYSTEM.md` 为准；武器管线以 `WEAPON_SYSTEM.md` + `WeaponManager.gd` 为准。 |
| **改代码即改文档** | 移动脚本路径、增删 autoload、改 API 字段时，至少更新对应专文 + 本文件 **§6** 一行 +（若属冗余/架构）**§8/§9** 勾选。 |

---

## 模块文档

实现细节以 [../README.md](../README.md#主题--主文档权威分工) 中的「主题 → 主文档」表为准。本文件 §4.2 / §8 / §9 保留问题台账与对齐核对，不重复模块索引。
