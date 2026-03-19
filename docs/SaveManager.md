# SaveManager 说明文档

SaveManager 是负责**设置存档**的全局单例（autoload）。**游戏存档**（背包、技能、属性）由 `CharacterDataManager` 通过 API 云端保存，不在此模块。

---

## 一、概述

| 项 | 说明 |
|----|------|
| **脚本路径** | `autoload/SaveManager.gd` |
| **Autoload 名称** | `SaveManager` |
| **设置存档路径** | `user://SettingsData`（加密） |
| **游戏存档** | 由 `CharacterDataManager` 负责，见 `docs/CharacterDataManager.md` |

---

## 二、设置存档（当前实现）

- **写入**：监听 `SettingSignal.set_setting_dictionary`，收到后使用 `FileAccess.open_encrypted_with_pass(SETTINGS_SAVE_PATH, WRITE, "Desahuman")` 将字典 JSON 后写入。
- **读取**：`load_settings_data()` 在 `_ready` 中调用，若存在设置文件则解密读取并 `SettingSignal.emit_load_setting_data(loaded_data)`，由 SettingData 等订阅并应用（窗口模式、分辨率、音量、热键等）。

---

## 三、游戏存档（CharacterDataManager）

游戏存档（背包、技能、属性）**不由 SaveManager 处理**，由 `CharacterDataManager` 统一负责：

- **加载**：`CharacterDataManager.load_and_apply()` 从 API 拉取
- **保存**：`CharacterDataManager.save_to_api()` 写入 API
- **快照/恢复**：场景切换时 `snapshot_before_scene_change()` / `restore_to_player()`

详见 `docs/CharacterDataManager.md`。

---

## 四、依赖

| 路径/依赖 | 说明 |
|-----------|------|
| `autoload/SettingSignal.gd` | 设置字典的保存与加载信号 |
| `autoload/SettingData.gd` | 提供设置字典、接收加载后的数据 |
