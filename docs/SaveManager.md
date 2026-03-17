# SaveManager 说明文档

SaveManager 是负责**设置存档**与**游戏存档**的全局单例（autoload），并提供**定时自动保存**（背包 + 技能）。设置与游戏存档分离：设置使用固定路径与加密；游戏存档包含背包与技能数据，并在规定时间间隔内自动写入。

---

## 一、概述

| 项 | 说明 |
|----|------|
| **脚本路径** | `autoload/SaveManager.gd` |
| **Autoload 名称** | `SaveManager` |
| **设置存档路径** | `user://SettingsData`（加密） |
| **游戏存档路径** | `user://GameSaveData`（加密） |
| **自动保存间隔** | 默认 120 秒（可配置常量 `AUTO_SAVE_INTERVAL_SEC`） |

---

## 二、设置存档（原有逻辑）

- **写入**：监听 `SettingSignal.set_setting_dictionary`，收到后使用 `FileAccess.open_encrypted_with_pass(SETTINGS_SAVE_PATH, WRITE, "Desahuman")` 将字典 JSON 后写入一行。
- **读取**：`load_settings_data()` 在 `_ready` 中调用，若存在设置文件则解密读取并 `SettingSignal.emit_load_setting_data(loaded_data)`，由 SettingData 等订阅并应用（窗口模式、分辨率、音量、热键等）。

设置相关逻辑未改动，仅与游戏存档共用同一个 SaveManager 节点。

---

## 三、游戏存档（背包 + 技能）

### 3.1 保存内容

- **背包**：来自 `InventoryManager`。按槽位序列化：每个槽位为 `null` 或 `{ "id": "物品ID", "qty": 数量 }`，保证槽位顺序一致。
- **技能**：来自 `SkillManager`。包含各技能等级与剩余冷却，以及技能栏槽位对应的技能名列表（用于还原快捷栏）。

### 3.2 存档格式（逻辑结构）

写入前会先拼成一个大字典，再 JSON 序列化并加密写入 `user://GameSaveData`：

```gdscript
{
  "inventory": [ null, { "id": "101", "qty": 5 }, ... ],  # 长度 = max_slots
  "skills": { "技能名": { "level": 1, "cooldown_remaining": 0.0 }, ... },
  "skill_bar": [ "技能名1", "", "技能名2", "" ]           # 与技能栏槽位一一对应
}
```

### 3.3 提供的接口

- **save_game()**  
  - 从 `InventoryManager` 取可序列化背包数据，从 `SkillManager.save_skills_data()` 取技能数据（已含 `skill_bar`），合并后加密写入 `user://GameSaveData`。  
  - 若未进入游戏（无 InventoryManager/SkillManager 等），可做存在性检查再写入，避免报错。

- **load_game() -> bool**  
  - 若 `user://GameSaveData` 不存在则返回 `false`。  
  - 否则解密读取、解析 JSON，调用 `InventoryManager.load_serializable_inventory(data["inventory"])` 与 `SkillManager.load_skills_data(data["skills"])`（技能数据中包含 `skill_bar` 的还原）。  
  - 成功返回 `true`。

- **start_auto_save()**  
  - 创建并启动一个单次间隔为 `AUTO_SAVE_INTERVAL_SEC` 的定时器，每次超时执行 `save_game()` 并再次等待相同间隔，实现周期自动保存。  
  - 建议在进入可游玩场景（如训练场、主关卡）时调用。

- **stop_auto_save()**  
  - 停止并释放自动保存定时器。  
  - 建议在离开可游玩场景（返回主菜单、读档切场景等）时调用。

---

## 四、与 InventoryManager / SkillManager 的协作

- **InventoryManager**  
  - 需实现：  
    - `get_serializable_inventory() -> Array`：返回长度为 `max_slots` 的数组，元素为 `null` 或 `{ "id": item.data.id, "qty": item.quantity }`。  
    - `load_serializable_inventory(data: Array) -> void`：清空当前背包后，按槽位索引逐格恢复（若某格有 `id`/`qty` 则用 `item_database` 取 ItemData 并放入对应槽位）。  
  - 这样 SaveManager 只依赖这两个接口，不关心背包内部实现。

- **SkillManager**  
  - 已有 `save_skills_data() -> Dictionary` 与 `load_skills_data(data: Dictionary)`。  
  - 扩展为：  
    - 保存时在返回的字典中增加 `"skill_bar"`：数组，长度为技能栏槽位数，元素为技能名（字符串）或空字符串表示空槽。  
    - 加载时若存在 `"skill_bar"`，则按槽位调用 `get_skill(name)` 并写入 `skill_bar[i]`，实现技能栏还原。

---

## 五、使用流程建议

### 5.1 本地存档（SaveManager 设计，若实现）

1. **进入可游玩场景时**  
   - 若存在存档且需要读档：调用 `SaveManager.load_game()`，根据返回值决定是否提示“无存档”或应用存档。  
   - 调用 `SaveManager.start_auto_save()`，开始按间隔自动保存。

2. **离开可游玩场景时**  
   - 调用 `SaveManager.stop_auto_save()`，避免在主菜单等界面仍写入游戏存档。

3. **手动存盘**  
   - 在暂停菜单、存档点等处调用 `SaveManager.save_game()` 即可。

### 5.2 API 云端存档（当前实现）

- **进入游戏世界**（`world.gd`）：`_load_player_data_from_api()` 从 `ApiManager` 加载背包与技能。
- **自动保存**：`world.gd` 每 120 秒调用 `_save_player_data_to_api()` 保存到服务器。
- **退出到主菜单**（`PauseManager.exit_to_main_menu()`）：退出前调用 `_save_player_data_to_api()`。
- **角色 ID**：`UserManager.current_character_id` 在登录成功后由 `/me` 接口填充。

---

## 六、加密与安全

- 游戏存档与设置存档均使用 `FileAccess.open_encrypted_with_pass(..., "Desahuman")`，密钥写死在代码中。  
- 若需区分正式/测试环境或提高安全性，可将密钥抽成配置或从外部注入，避免敏感信息泄露。

---

## 七、文件与依赖一览

| 路径/依赖 | 说明 |
|-----------|------|
| `autoload/SaveManager.gd` | 设置存档、游戏存档、自动保存逻辑 |
| `autoload/SettingSignal.gd` | 设置字典的保存与加载信号 |
| `autoload/SettingData.gd` | 提供设置字典、接收加载后的数据 |
| `addons/xuanBag/scripts/InventoryManager.gd` | `get_serializable_inventory` / `load_serializable_inventory` |
| `autoload/SkillManager.gd` | `save_skills_data`（含 skill_bar）/ `load_skills_data` |

以上为 SaveManager 的完整说明。
