# SaveManager 说明文档
[← 文档索引](../README.md#文档索引)

SaveManager 是负责**设置存档**的全局单例（autoload）。**游戏存档**（背包、技能、属性）由 `CharacterDataManager` 通过 **API 云端** 保存；**本地加密快存**（防闪退、版本号）由 **`LocalCharacterSave`** 负责，不在此模块。

---

## 一、概述

| 项 | 说明 |
|----|------|
| **脚本路径** | `autoload/SaveManager.gd` |
| **Autoload 名称** | `SaveManager` |
| **设置存档路径** | `user://SettingsData`（加密） |
| **游戏存档** | 由 [CharacterDataManager.md](CharacterDataManager.md) 负责 |

---

## 二、设置存档（当前实现）

- **写入**：监听 `SettingSignal.set_setting_dictionary`，收到后使用 `FileAccess.open_encrypted_with_pass`（密钥与脚本内 `SETTINGS_ENCRYPTION_KEY` 一致，当前为 `"Desahuman"`）将字典 `JSON.stringify` 后单行写入。
- **读取**：`load_settings_data()` 在 `_ready` 中调用；解密后读取全文，`JSON.parse` 成功且根为 `Dictionary` 时 `SettingSignal.emit_load_setting_data`。读写失败会 `push_error` / `push_warning`，不会抛异常。

---

## 三、游戏存档（CharacterDataManager + LocalCharacterSave）

游戏进度 **不由 SaveManager 处理**，由 `CharacterDataManager` 统一负责云端与内存快照；**本地快存**见 **`LocalCharacterSave`**：

- **加载**：`CharacterDataManager.load_and_apply()` 从 API 拉取
- **保存**：`CharacterDataManager.save_to_api()` 写入 API
- **快照/恢复**：场景切换时 `snapshot_before_scene_change()` / `restore_to_player()`
- **本地快存 / 版本号 / 同步策略**：[LOCAL_AND_CLOUD_SAVE.md](LOCAL_AND_CLOUD_SAVE.md)

---

## 四、依赖

| 路径/依赖 | 说明 |
|-----------|------|
| `autoload/SettingSignal.gd` | 设置字典的保存与加载信号 |
| `autoload/SettingData.gd` | 提供设置字典、接收加载后的数据 |
