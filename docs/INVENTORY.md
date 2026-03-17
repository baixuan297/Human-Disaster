# 背包系统（Inventory）说明文档

本文档说明项目中与 **背包 / 物品（Inventory）** 相关的全部逻辑、数据流与扩展方式。背包功能由插件 **xuanBag** 提供，通过全局单例 **InventoryManager** 与场景 **InventoryUI** 配合使用。

---

## 一、整体架构

```
                    ┌─────────────────────────────────────┐
                    │         InventoryManager            │
                    │  (autoload 单例，唯一数据源)          │
                    │  items[] / current_bag / 信号       │
                    └──────────────┬──────────────────────┘
                                   │ 信号 / API
         ┌────────────────────────┼────────────────────────┐
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   InventoryUI   │    │  游戏逻辑调用   │    │  sample / 宝箱   │
│  (背包界面)      │    │ add_item / use  │    │ add_item_by_*   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │
         ├── ItemSlot（多个）── 显示、点击、拖拽
         └── ItemTooltip ── 悬停说明
```

- **数据**：只存在于 `InventoryManager`（单例），槽位数组 `items: Array[InventoryItem]`，最大槽位数 `max_slots`（默认 60）。
- **界面**：`InventoryUI` 只负责展示与操作，通过信号和 `InventoryManager` 的 API 读写数据，不持有备份。
- **物品定义**：来自 JSON（见 `addons/xuanBag/data/`），由 `ItemDatabase` 加载，`InventoryManager` 在 `_ready` 中创建并持有 `ItemDatabase`。

---

## 二、插件与全局单例

### 2.1 插件 xuanBag

- **路径**：`addons/xuanBag/`
- **入口**：`plugin.cfg` 指定 `script="xuanBag.gd"`。
- **作用**：在编辑器中启用时，通过 `add_autoload_singleton("InventoryManager", ...)` 注册全局单例；禁用时 `remove_autoload_singleton`。
- **项目中的使用**：在 `project.godot` 的 `[autoload]` 里已直接配置：
  ```ini
  InventoryManager="*res://addons/xuanBag/scripts/InventoryManager.gd"
  ```
  因此即使关闭插件，只要 autoload 存在，背包逻辑仍可用。

### 2.2 InventoryManager（核心单例）

**文件**：`addons/xuanBag/scripts/InventoryManager.gd`  
**类型**：`Node`，作为 autoload 常驻场景树。

#### 信号

| 信号 | 参数 | 含义 |
|------|------|------|
| `item_added` | `item: InventoryItem, slot_index: int` | 物品被加入某个槽位（含堆叠） |
| `item_removed` | `item: InventoryItem, slot_index: int` | 某槽位物品数量减少或清空 |
| `item_used` | `item: InventoryItem` | 某槽位物品被“使用” |
| `inventory_changed` | 无 | 背包数据有任意变化时发出，UI 用于整表刷新 |
| `bag_changed` | `bag_type: String` | 当前分类背包切换（Weapon/Potion/…） |

#### 主要属性

- `max_slots: int = 60`：背包总槽位数。
- `items: Array[InventoryItem]`：按槽位索引存放，空槽为 `null`。
- `current_bag_type: String`：当前筛选的背包类型（如 `"WEAPON"`），用于 `get_current_bag_items()`。
- `current_filter_name: String`：名称搜索关键词。
- `current_sort_mode: SortMode`：`NONE` / `BY_RARITY` / `BY_NAME`。
- `current_sort_order: bool`：排序方向（true 正序，false 倒序）。
- `item_database: ItemDatabase`：在 `_ready` 中 `ItemDatabase.new()` 并 `add_child`，用于根据 ID 取 `ItemData`。

#### 核心 API（简要）

- **添加**  
  - `add_item(item_data: ItemData, quantity: int = 1) -> bool`：先尝试堆叠，再占空槽。  
  - `add_item_by_id(item_id: String, quantity: int = 1) -> bool`  
  - `add_item_by_numeric_id(item_id: int, quantity: int = 1) -> bool`  
  成功时发 `item_added` 和 `inventory_changed`。
- **移除 / 删除**  
  - `remove_item(slot_index: int, quantity: int) -> bool`：减数量，可为 0 则清空槽位。  
  - `delete_item(slot_index: int)`：直接清空该槽。
- **移动**  
  - `move_item(from_slot: int, to_slot: int) -> bool`：可交换、堆叠或单纯移动。
- **使用**  
  - `use_item(slot_index: int) -> bool`：发出 `item_used`；若类型为 MATERIAL 或 QUEST，则自动 `remove_item(slot_index, 1)`。
- **查询**  
  - `get_item(slot_index: int) -> InventoryItem`  
  - `get_all_items()`、`get_items_of_rarity(...)`、`get_items_of_type(...)`、`get_items_by_name(...)`  
  - `get_current_bag_items() -> Array[InventoryItem]`：按当前背包类型 + 名称过滤 + 排序后的列表（UI 显示用）。  
  - `find_empty_slot() -> int`、`find_item_index(item: InventoryItem) -> int`  
  - `has_item(item_id: String, quantity: int = 1) -> bool`
- **背包 / 筛选 / 排序**  
  - `switch_bag(bag_type: String)`  
  - `set_name_filter(filter_text: String)`  
  - `set_sort_mode(mode: SortMode)`  
  - `toggle_sort_order()`

逻辑要点：  
- 添加时先遍历已有槽位尝试堆叠（同 `ItemData.id` 且未满 `max_stack`），再找空槽。  
- 移动时支持“堆叠到同种物品”或“交换两个槽位”。

---

## 三、数据层：ItemData 与 ItemDatabase

### 3.1 ItemData（Resource）

**文件**：`addons/xuanBag/scripts/item_data.gd`  
**类名**：`ItemData`（Resource）

表示**一类**物品的静态数据（不是背包里的一格）。

- **字段**：`id`, `name`, `description`, `icon`, `max_stack`, `item_type`, `rarity`, `sell_price`, `buy_price`。
- **ItemType 枚举**：`FOOD`, `WEAPON`, `POTION`, `TOOL`, `MATERIAL`, `QUEST`。
- **ItemRarity 枚举**：`COMMON`, `UNCOMMON`, `RARE`, `EPIC`, `LEGENDARY`。
- **方法**：`get_rarity_color() -> Color`，用于 UI 边框等染色。

### 3.2 ItemDatabase（Node）

**文件**：`addons/xuanBag/scripts/database.gd`  
**类名**：`ItemDatabase`

- 在 `_ready` 中调用 `load_json_from_folder()`，扫描 `res://addons/xuanBag/data/` 下所有文件，对每个文件调用 `load_items_from_json(file_path)`。
- JSON 格式：支持根节点为数组，或 `{ "items": [ ... ] }`。每个元素为字典，例如：
  - `item_id`, `item_name`, `item_desc`, `item_icon`, `max_stack`, `item_type`, `rarity`。
- `create_item_data_from_dict(data_dict)` 将字典转成 `ItemData`，并统一用 `str(item_id)` 作为 key 存入 `items_data`。
- 对外接口：`get_item_data(item_id: String)`、`get_item_data_by_id(item_id: int)`、`has_item`、`get_all_items`、`get_items_by_type` 等。

物品数据文件示例路径：

- `addons/xuanBag/data/dh游戏_物品表单.json`
- `addons/xuanBag/data/dh游戏_武器表单.json`

---

## 四、背包中的“一格”：InventoryItem

**文件**：`addons/xuanBag/scripts/item.gd`  
**类名**：`InventoryItem`（Resource）

表示背包**某一个槽位**里的物品实例（类型 + 数量）。

- **属性**：`data: ItemData`，`quantity: int`。
- **堆叠**：  
  - `can_stack_with(other_item: InventoryItem) -> bool`：同 `data.id` 且总数量不超过 `data.max_stack`。  
  - `stack_with(other: InventoryItem) -> int`：把 `other` 的数量尽可能合并到当前对象，返回 `other` 剩余数量。
- **拆分**：`split(amount: int) -> InventoryItem`：从当前数量中拆出 `amount`，返回新 `InventoryItem`，当前数量减少。

`InventoryManager` 的 `items` 数组里存的是 `InventoryItem` 或 `null`。

---

## 五、背包界面：InventoryUI

**文件**：`addons/xuanBag/scripts/Inventory.gd`  
**场景**：`addons/xuanBag/scene/Inventory.tscn`  
**类名**：`InventoryUI`（Control）

### 5.1 职责

- 显示当前背包分类下的物品列表（依赖 `InventoryManager.get_current_bag_items()`）。
- 提供分类切换（武器/药水/材料/食物/任务/工具）、搜索、排序、删除、关闭。
- 左键选中并显示右侧详情，右键使用物品，拖拽移动物品。

### 5.2 节点与引用

- **Top**：`bag_name`、`text_edit`（搜索框）。
- **Mid**：`grid_container`（槽位网格）、右侧 `item_info_*`（名称、类型、描述、图标等）。
- **Bottom**：分类按钮（Weapon / Potion / Material / Food / Quest / Tool）等。
- **动态**：`item_slots: Array[ItemSlot]`，由 `setup_slots()` 根据 `inventory_manager.max_slots` 实例化 `item_slot.tscn` 并连接信号。

### 5.3 生命周期与暂停

- `_ready` 中：`PauseManager.open_inventory()`（将游戏设为“背包打开”状态，通常伴随暂停与显示鼠标）、`add_to_group("inventory_ui")`、`inventory_manager = InventoryManager`、`setup_slots()`、`connect_signals()`、默认 `switch_bag("Weapon")`，并设置 `process_mode = PROCESS_MODE_ALWAYS` 以便暂停时仍可操作 UI。
- 关闭时：`visible = false`、`PauseManager.close_inventory()`、`UiManager.close_current_ui()`。
- `_input`：检测 `ui_cancel`（如 Esc）并关闭背包。

### 5.4 与 InventoryManager 的信号连接

- `item_added` / `item_removed`：更新对应槽位的 `ItemSlot.set_item(...)`。
- `inventory_changed`：调用 `update_display()`，根据 `get_current_bag_items()` 重新填充所有槽位显示。
- `bag_changed`：更新标题、高亮当前分类、清空搜索、再 `update_display()`。

### 5.5 槽位索引的“显示列表”与“真实槽位”

- 界面上看到的是**当前分类 + 过滤 + 排序**后的列表 `get_current_bag_items()`，列表下标 0、1、2… 是“显示用索引”。
- 背包真实槽位是 `items` 的 0..max_slots-1。
- 右键使用、拖拽移动、删除时，都通过 `find_item_index(item)` 把“显示列表中的物品”映射回“真实槽位索引”，再调用 `use_item(actual_index)` / `move_item(actual_from, actual_to)` / `delete_item(actual_index)`。

---

## 六、物品格：ItemSlot

**文件**：`addons/xuanBag/scripts/item_slot.gd`  
**场景**：`addons/xuanBag/scene/item_slot.tscn`  
**类名**：`ItemSlot`（Control）

### 6.1 作用

- 显示一个槽位的图标、数量、稀有度边框。
- 左键：选中 + 可开始拖拽；发出 `item_clicked`。
- 右键：发出 `item_right_clicked`（InventoryUI 里会调用 `use_item`）。
- 拖拽结束：检测鼠标下是否是另一个 ItemSlot，若是则发出 `item_dropped(from_slot, to_slot)`。

### 6.2 拖拽与选中

- `_start_drag()`：创建跟随鼠标的 `drag_preview`（TextureRect 显示当前物品图标），挂在 `get_tree().current_scene`。
- `_end_drag()`：用 `get_global_mouse_position()` 和 `get_tree().get_first_node_in_group("inventory_ui")` 下的 `item_slots` 做矩形检测，得到 `target_slot`，若与当前槽位不同则 `item_dropped.emit(self, target_slot)`。
- 选中状态：静态变量 `current_selected_slot` 记录当前选中的槽位，用于高亮和删除时“当前选中项”。

### 6.3 悬停提示

- `mouse_entered`：实例化 `item_tooltip.tscn`，调用 `show_tooltip(item, pos)`。
- `mouse_exited`：销毁该 tooltip 子节点。

---

## 七、物品提示：ItemTooltip

**文件**：`addons/xuanBag/scripts/item_tooltip.gd`  
**场景**：`addons/xuanBag/scene/item_tooltip.tscn`

- 根据 `InventoryItem` 与 `ItemData` 显示名称、类型、描述、数量；名称颜色使用 `get_rarity_color()`。
- 由 ItemSlot 在鼠标进入时创建并定位，移出时移除。

---

## 八、与暂停 / UI / 场景的集成

### 8.1 PauseManager

- **open_inventory()**：`push_state(PauseState.INVENTORY)`，通常会导致游戏暂停并显示鼠标。
- **close_inventory()**：`pop_state(PauseState.INVENTORY)`。
- 关闭 UI 时若当前是 `"InventoryUI"`，会调用 `close_inventory()`（见 `_close_ui_from_ui_manager`）。

### 8.2 UIManager

- 将 UI 名称 `"Inventory"` 映射为 `"InventoryUI"`（用于统一打开/关闭逻辑）。

### 8.3 SceneManager

- 场景名 `"InventoryUI"` 对应场景路径：`res://addons/xuanBag/scene/Inventory.tscn`。  
  打开背包时一般通过 UiManager/SceneManager 加载该场景或节点，并调用 `PauseManager.open_inventory()`；具体由你项目里打开背包的入口决定。

---

## 九、游戏内如何与背包交互

### 9.1 添加物品（你项目中的用法）

- **宝箱 / 交互**：在 `test/InteractionComponent.gd` 中，当玩家与“宝箱”类物体交互时，会调用一串 `InventoryManager.add_item_by_numeric_id(...)`，例如：
  - 201、202、203（武器类）
  - 251、252、253（弹药类）
  - 101、102、103（门禁卡、星币、改名卡）
  - 100（实验室钥匙）
  等。数字 ID 与 `addons/xuanBag/data/` 下 JSON 中的 `item_id` 一致。
- **示例脚本**：`addons/xuanBag/scripts/sample.gd` 中同样有通过 `inventory.add_item_by_numeric_id(...)` 批量添加的示例，并连接了 `item_used` 做使用反馈（如门禁卡、星币、钥匙等）。

### 9.2 打开 / 关闭背包

- 打开：需要由你的游戏逻辑（例如按键、菜单）加载 Inventory 场景或节点，并调用 `PauseManager.open_inventory()`；若使用 UiManager，则按你项目里打开 UI 的流程（如 `UiManager.open_ui("Inventory")` 之类）。
- 关闭：InventoryUI 内关闭按钮和 Esc 会调用 `PauseManager.close_inventory()` 和 `UiManager.close_current_ui()`。
- **角色菜单**：`Script/menu/characterInfo/character_menu.gd` 中有 `pauseManager.close_inventory()`，用于在打开角色信息等界面时关闭背包。

### 9.3 使用物品

- 在 UI 中：右键槽位 → InventoryUI 取 `get_current_bag_items()` 中对应项 → `find_item_index` 得到真实槽位 → `InventoryManager.use_item(actual_index)`。
- `use_item` 会发出 `item_used(item)`。游戏逻辑可连接该信号，根据 `item.data.item_type` 或 `item.data.id` 执行不同效果（如 `sample.gd` 中的门禁卡、星币、钥匙等）。  
  MATERIAL / QUEST 类型会在 `use_item` 内部自动扣 1 数量。

### 9.4 查询是否拥有物品

- `InventoryManager.has_item(item_id: String, quantity: int = 1) -> bool`  
  示例：`sample.gd` 中的 `has_item_by_id(item_id: int)` 内部转为字符串再调 `has_item`。

---

## 十、删除确认与其它 UI

- **item_delete**：`addons/xuanBag/scene/item_delete.tscn` 与对应脚本，用于删除物品时的二次确认；InventoryUI 在点击删除按钮时实例化，确认后调用 `delete_item(actual_index)` 并刷新详情。

---

## 十一、数据与扩展建议

### 11.1 新增物品

1. 在 `addons/xuanBag/data/` 下 JSON 中增加一条，包含 `item_id`, `item_name`, `item_desc`, `item_icon`, `max_stack`, `item_type`, `rarity` 等。
2. 若使用新 JSON 文件，需保证被 `ItemDatabase.load_json_from_folder()` 扫描到（当前是遍历该目录下所有文件）。
3. 游戏里通过 `InventoryManager.add_item_by_numeric_id(item_id, quantity)` 或 `add_item_by_id(str_id, quantity)` 添加。

### 11.2 新增“使用”逻辑

- 连接 `InventoryManager.item_used`，在回调中根据 `item.data.item_type` 或 `item.data.id` 分支处理（参考 `sample.gd`）。
- 不需要在背包内部写具体效果，只通过信号与业务层解耦。

### 11.3 注意事项

- 槽位数量由 `InventoryManager.max_slots` 决定，修改后需保证 UI 的 `setup_slots()` 会创建对应数量的 ItemSlot。
- 当前“背包类型”只是筛选与显示分类，真实数据仍是一个线性 `items` 数组；若未来要做多背包分页，需要在 Manager 层扩展数据结构和 API。

---

## 十二、文件与场景一览

| 路径 | 说明 |
|------|------|
| `addons/xuanBag/scripts/InventoryManager.gd` | 背包数据与逻辑（autoload） |
| `addons/xuanBag/scripts/Inventory.gd` | 背包界面逻辑（InventoryUI） |
| `addons/xuanBag/scripts/item.gd` | 单格物品实例（InventoryItem） |
| `addons/xuanBag/scripts/item_data.gd` | 物品静态数据（ItemData） |
| `addons/xuanBag/scripts/database.gd` | 物品表加载（ItemDatabase） |
| `addons/xuanBag/scripts/item_slot.gd` | 单个槽位 UI（ItemSlot） |
| `addons/xuanBag/scripts/item_tooltip.gd` | 悬停提示 |
| `addons/xuanBag/scripts/item_delete.gd` | 删除确认（与 item_delete 场景对应） |
| `addons/xuanBag/scripts/sample.gd` | 示例：打开背包、监听 item_used、批量添加 |
| `addons/xuanBag/scene/Inventory.tscn` | 背包主场景 |
| `addons/xuanBag/scene/item_slot.tscn` | 槽位场景 |
| `addons/xuanBag/scene/item_tooltip.tscn` | 提示框场景 |
| `addons/xuanBag/data/*.json` | 物品与武器等 JSON 数据 |
| `autoload/PauseManager.gd` | open_inventory / close_inventory |
| `autoload/UIManager.gd` | "Inventory" → "InventoryUI" |
| `autoload/SceneManager.gd` | "InventoryUI" 场景路径 |
| `test/InteractionComponent.gd` | 宝箱交互中 add_item_by_numeric_id 调用 |

以上即项目中与 Inventory 相关的全部逻辑与用法说明；按本文可从数据、UI、到与游戏其它系统的衔接做修改与扩展。
