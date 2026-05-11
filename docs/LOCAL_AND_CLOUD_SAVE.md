# 本地与云端存档方案

本文描述 **Godot 客户端** 与 **FastAPI `/characters/...`** 之间的存档分工、同步策略、版本号语义与后续可扩展点（服务端乐观锁等）。**实现入口**：`LocalCharacterSave.gd` + `CharacterDataManager.gd`。

---

## 一、职责划分

| 层 | 职责 | 实现 |
|----|------|------|
| **云端（权威）** | 背包、技能、基因、角色属性、`loadout`、合并写入的 **`scene_state`**（场景路径、坐标、已拾取物等） | `ApiManager` + `CharacterDataManager.save_to_api` |
| **本地加密快存** | 防闪退、减卡顿、离线缓冲；与云端同结构的快照副本 | **`LocalCharacterSave`**：`user://local_character_save/{character_id}.lcs` |
| **内存快照** | 切场景前后减少重复 API | `CharacterDataManager` 现有 `_stats_snapshot` 等 |

**与 `SaveManager` 区分**：`SaveManager` 仅 **游戏设置**（`user://SettingsData`）。角色进度 **不** 写入该文件。

---

## 二、版本号语义（客户端）

每条本地快存 JSON 根级包含：

| 字段 | 含义 |
|------|------|
| **`schema_version`** | 文件格式版本（当前为 `1`）；`read_save_dict` 对 `schema_version < SCHEMA_VERSION` 的根字典做**轻量迁移**（补全 `local_revision`/`cloud_ack_revision`/`pending_cloud_sync`/`client_blob`） |
| **`local_revision`** | 单调递增；**每次写入本地快存** +1 |
| **`cloud_ack_revision`** | 最近一次 **全量云端保存成功** 时所对应的 `local_revision` |
| **`pending_cloud_sync`** | `local_revision > cloud_ack_revision` 时为 `true`，表示本地较云端更新，需再次同步 |

**冲突与回滚（当前策略）**：

1. **登录并成功拉取云端**：以云端数据为权威，调用 **`write_cloud_authoritative`**，将 `local_revision` 与 `cloud_ack_revision` **重置为 1**，`pending_cloud_sync = false`。
2. **游玩中**：定时器 + 切场景前 + 每次发起 `save_to_api` 前写入本地 → `local_revision` 增加；若尚未收到本次 API 成功回调，则 **`pending_cloud_sync = true`**。
3. **全量 API 保存成功**（背包 + 技能 + 基因 + stats 均成功）：**`mark_full_api_synced`**，令 `cloud_ack_revision = local_revision`，`pending = false`。
4. **任一 API 失败或超时**：不调用 `mark_full_api_synced`，保持 `pending = true`，便于 UI 提示「重试同步」。

> **后续增强（推荐）**：在 PostgreSQL `character_stats`（或等价表）增加 **`server_revision`**（BIGINT，每次 `save_character_stats` 事务 +1），`GET /characters/{id}/stats` 返回该字段；客户端在 POST 体携带 **`client_expected_revision`**，不匹配则返回 **409**，由 UI 决定覆盖/合并。届时可将 `cloud_ack_revision` 与 `server_revision` 对齐或建立映射表。

---

## 三、同步时序

### 3.1 登录后首次进游戏

1. `CharacterDataManager.load_and_apply()` → 并行 `load_inventory` / `load_skills` / `load_stats` / `load_genes` / `load_scene_state`。
2. 全部回调完成后 → **`LocalCharacterSave.write_cloud_authoritative(...)`**：用当前内存快照覆盖本地文件，版本基线重置（见上节）。

### 3.2 游玩中

1. **定时**（默认约 **18s**，常量 `LOCAL_CHECKPOINT_INTERVAL_SEC`）：若有玩家且已选角色 → `_take_snapshot()` → **本地快存**。
2. **切场景前**：`snapshot_before_scene_change()` → 快照 + **本地快存**（重点防闪退）。
3. **发起云端保存**：`save_to_api()` 在 `_take_snapshot()` 之后立即 **再写一次本地**，再发 API；**并行 4 路** `POST`：`inventory`、`skills`、`genes`、`stats`（**`scene_state` 与 `loadout` 嵌在 `stats` 请求体**，不设单独第 5 路 `scene_state`，与后端同事务写入 `character_stats`）；全部成功后再 **`mark_full_api_synced`**。独立 `GET/POST .../scene_state` 仍用于登录拉取等场景。

### 3.3 离线（当前阶段）

- 若 API 失败：本地文件仍已通过快存更新，**`pending_cloud_sync == true`**。
- **尚未实现**：启动时「仅本地、无网络」自动灌回 Player（需在登录/选角流程中显式分支并处理与云端的合并规则）。上线后应调用 **`CharacterDataManager.save_to_api(..., true)`** 强制同步。

查询：`CharacterDataManager.has_pending_cloud_sync()`。

---

## 四、本地加密

- 与 `SaveManager` 相同技术栈：**`FileAccess.open_encrypted_with_pass`** + 单行 **`JSON.stringify`**。
- 口令见 **`LocalCharacterSave.ENCRYPTION_PASS`**（与设置档分离）；**修改口令会导致旧快存无法解密**，需做迁移或清档说明。
- **防篡改**：加密仅为「提高门槛」，非密码学意义上的防作弊；竞技或经济敏感数据应以 **服务端校验** 为准。

---

## 五、公开 API 摘要

| 调用方 | 方法 |
|--------|------|
| 任意（战斗节点、Boss 胜利等） | `CharacterDataManager.save_local_checkpoint_now()`：仅快照 + 本地快存 |
| UI「同步到云端」 | `CharacterDataManager.save_to_api(Callable, true)` |
| UI 提示 | `CharacterDataManager.has_pending_cloud_sync()` |

**信号**：`LocalCharacterSave.local_checkpoint_written`、`local_save_read_failed`（解析失败等）。

---

## 六、相关文件

| 文件 | 说明 |
|------|------|
| `autoload/LocalCharacterSave.gd` | 本地加密 `.lcs`、版本号、`client_blob`、`read_client_blob` |
| `autoload/CharacterDataManager.gd` | 快照、API、定时快存、`_gather_client_blob` |
| `autoload/GameDataManager.gd` | 静态定义磁盘缓存 `game_data_definitions_cache.enc`、离线兜底 |
| `autoload/SaveManager.gd` | 仅设置 |
| `StarshipBackend/PSQL_DH/main.py` | `save_character_stats`、`scene_state` 合并写入 |

更细的 API 与快照字段见 [CharacterDataManager.md](CharacterDataManager.md)；静态数据见 [GameDataManager.md](GameDataManager.md)。

---

## 七、游戏中「还可缓存」的数据（评估）

下列数据**未**全部进当前云端 FastAPI 路径时，可优先考虑 **本地缓存 / 将来进库** 的策略。

| 数据 | 当前去向 | 建议本地缓存 | 建议云端 / 库 |
|------|----------|--------------|---------------|
| **物品/技能/基因/敌人定义** | `GameDataManager` 内存，API `/game-data/*` | ✅ **`user://game_data_definitions_cache.enc`**（全量成功拉取后写入；任一拉取失败时 **`try_restore_definitions_from_disk_cache()`** 兜底） | 已有表 `game.items/skills/genes/enemies`；客户端不直连库 |
| **角色 Stats / 背包 / 技能 / 基因 / scene_state** | 已进 `.lcs` 与 API | ✅ 已实现 | 已有 `character_stats`、`inventory`、`character_skills`、基因相关表 |
| **教程运行时步骤**（非 `tutorial_completed`） | 仅 `TutorialManager` 内存 | ✅ **`client_blob`**（`tutorial_step`、`tutorial_in_progress` 等） | 可选：写入 `character_stats.extra` JSON 或独立 `character_tutorial_state` |
| **当前场景路径**（与 `scene_state` 重叠） | `scene_state.scene_path` 已持久化 | ✅ `client_blob.current_scene_path` 作冗余/崩溃瞬间补充 | 已含于 `scene_state` |
| **技能冷却剩余** | `SkillManager.save_skills_data` 已在快照 | ✅ 已在 `.lcs` | 已有 `character_skills`；若后端只存等级不存 CD，可扩展列或 JSON |
| **任务 / 成就 / 地图发现** | DB 有 `character_quests`、`character_achievements`、`discovered_locations`，**Godot 当前未接 FastAPI** | 本地可增 **`progress_blob`**（与 `client_blob` 并列）待接 API 后删除 | **需新增或补齐** `GET/POST /characters/{id}/quests` 等路由 + 与 `game.*` 表对齐 |
| **角色综合进度**（等级条、大地图坐标历史） | `game.character_progress` 在 schema 中存在 | 可镜像进 `.lcs` 的 `client_blob` 或独立节 | 确认 ORM/路由是否实现；若无则迁移 + `main.py` |
| **货币钱包** | `game.character_currencies` | 本地可缓存最后已知值 | 需 **`/characters/{id}/currencies`** 读写与反作弊校验 |
| **邮件 / 交易** | 多表 | 一般 **不做** 全量本地加密包，仅会话级内存 + 分页拉取 | 保持服务端权威 |

---

## 八、本次已落地的扩展

1. **`LocalCharacterSave` → `client_blob`**  
   - 由 **`CharacterDataManager._gather_client_blob()`** 写入：`tutorial_*`、`current_scene_path`。  
   - 读取：**`LocalCharacterSave.read_client_blob(character_id)`**（供日后离线恢复教程/场景引导）。

2. **`GameDataManager` → 静态定义磁盘缓存**  
   - 路径：**`user://game_data_definitions_cache.enc`**（常量见脚本）。  
   - **全量拉取成功**后自动 `_persist_definitions_disk_cache()`。  
   - **任一 `/game-data` 请求失败**触发 `_on_load_error` 时，若磁盘缓存完整可读，则 **`try_restore_definitions_from_disk_cache()`** 灌入内存并 **`all_data_loaded.emit()`**（Toast 提示使用本地配置）。

---

## 九、数据库与后端连接（建议）

以下在 **`docs/DATABASE_SCHEMA.md`** 中多已存在表定义；缺口主要在 **FastAPI 路由与 Godot `ApiManager`** 是否暴露。

| 主题 | 是否新建表 | 建议 |
|------|------------|------|
| **存档乐观锁 / 冲突检测** | 否 | 在 **`game.character_stats`** 增加 **`data_revision BIGSERIAL`** 或 **`updated_at` + 版本整数**，`save_character_stats` 在事务内 `UPDATE ... SET revision = revision + 1 WHERE revision = :expected` |
| **任务 / 成就 / 发现点** | 否（表已有） | 为 `character_quests`、`character_achievements`、`discovered_locations` 增加 **REST**：列表、批量保存、与 Godot 本地 `progress_blob` 对账 |
| **货币** | 否 | `character_currencies` + API；敏感操作仅服务端 |
| **战斗 Checkpoint（波次、Boss 阶段）** | 可选 | **轻量**：扩展现有 **`scene_state` JSON**（如 `battle_checkpoint: { "wave": 2 }`）避免新表；**重量**：`game.character_battle_sessions`（`character_id`, `map_id`, `state_json`, `updated_at`） |
| **审计 / 回滚** | 可选 | `character_stats_audit`（历史行）或逻辑复制到冷存储；成本高，优先 **revision + 客户端 pending 标记** |

**与 Godot 的衔接顺序**：先 **DB 迁移** → **Pydantic schema + main.py** → **`ApiManager` + `CharacterDataManager`** → 再考虑把对应块从 `client_blob` 迁到正式 API 并从 `.lcs` 中删除冗余。
