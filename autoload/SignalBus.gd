extends Node
#
## ==================== 武器系统事件 ====================
#
### 武器被装备 (装备到某个槽位)
#signal weapon_equipped(weapon_data: WeaponData, slot_index: int)
#
### 武器被卸下
#signal weapon_unequipped(slot_index: int)
#
### 武器切换 (从槽位A切换到槽位B)
#signal weapon_switched(from_slot: int, to_slot: int)
#
### 武器开火
#signal weapon_fired(weapon_data: WeaponData, projectile_position: Vector3)
#
### 弹药变化
#signal ammo_changed(weapon_name: String, current: int, reserve: int)
#
### 武器被拾取
#signal weapon_picked_up(weapon_data: WeaponData)
#
### 武器被丢弃
#signal weapon_dropped(weapon_data: WeaponData, drop_position: Vector3)
#
### 武器槽位已满 (尝试拾取但背包满了)
#signal weapon_slots_full()
#
### 武器需要装填
#signal weapon_needs_reload(weapon_name: String)
#
### 装填完成
#signal weapon_reloaded(weapon_name: String, ammo_loaded: int)
#
## ==================== 交互事件 ====================
#
### 可交互对象进入范围
#signal interactable_entered(interactable: Node)
#
### 可交互对象离开范围
#signal interactable_exited(interactable: Node)
#
### 交互执行
#signal interacted_with(interactable: Node)
#
## ==================== UI事件 ====================
#
### 显示提示信息
#signal show_hint(text: String, duration: float)
#
### 显示拾取提示
#signal show_pickup_prompt(item_name: String, can_pickup: bool)
#
### 隐藏拾取提示
#signal hide_pickup_prompt()
#
## ==================== 调试工具 ====================
#
### 打印所有连接的信号 (调试用)
#func debug_print_connections() -> void:
	#print("=== GameEvents 信号连接数 ===")
	#var signals_list = get_signal_list()
	#for sig in signals_list:
		#var connections = get_signal_connection_list(sig["name"])
		#print("%s: %d 个连接" % [sig["name"], connections.size()])
