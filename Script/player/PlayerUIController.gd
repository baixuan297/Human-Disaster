extends Node3D
## UI 层：仅通过信号更新 health_bar、health_label、crosshair、ammo 等，与 Player/WeaponManager 解耦。
## 当 inventory/characterMenu/暂停菜单 打开时自动隐藏 HUD，避免遮挡。

# 注入
var ui_layer: CanvasLayer
var health_bar: ProgressBar
var health_label: Label
var crosshair: Control
var crosshairhit: Control
var ammo_container: Control
var no_more_bullet: Label
var hit_rect: Control
var ammo_current_label: Label
var ammo_reserve_label: Label


func setup(
	p_ui_layer: CanvasLayer,
	p_health_bar: ProgressBar,
	p_health_label: Label,
	p_crosshair: Control,
	p_crosshairhit: Control,
	p_ammo_container: Control,
	p_no_more_bullet: Label,
	p_hit_rect: Control
) -> void:
	ui_layer = p_ui_layer
	health_bar = p_health_bar
	health_label = p_health_label
	crosshair = p_crosshair
	crosshairhit = p_crosshairhit
	ammo_container = p_ammo_container
	no_more_bullet = p_no_more_bullet
	hit_rect = p_hit_rect

	if ammo_container != null:
		ammo_current_label = ammo_container.get_node_or_null("CurrentAmmo")
		ammo_reserve_label = ammo_container.get_node_or_null("reserve")

	# 其他 UI 打开时隐藏 HUD
	if not PauseManager.state_changed.is_connected(_on_pause_state_changed):
		PauseManager.state_changed.connect(_on_pause_state_changed)
	_update_hud_visibility(PauseManager.get_current_state())


func _on_pause_state_changed(new_state: PauseManager.PauseState) -> void:
	_update_hud_visibility(new_state)


func _update_hud_visibility(state: PauseManager.PauseState) -> void:
	var hide_hud := state in [
		PauseManager.PauseState.INVENTORY,
		PauseManager.PauseState.CHARACTERINFO,
		PauseManager.PauseState.PAUSED,
	]
	if ui_layer != null:
		ui_layer.visible = not hide_hud
		# 重新显示 HUD 时强制同步一次血条（防止信号丢失导致不同步）
		if not hide_hud:
			_sync_health_from_player()


func _sync_health_from_player() -> void:
	var p := CharacterDataManager.get_player() if CharacterDataManager else null
	if p == null:
		return
	var ps = p.get("player_stats")
	if ps and ps.get("current_health") != null and ps.get("current_max_health") != null:
		_apply_health_ui(float(ps.current_health), float(ps.current_max_health))


func _apply_health_ui(current: float, maximum: float) -> void:
	if health_bar != null:
		health_bar.max_value = maximum
		health_bar.value = current
	if health_label != null:
		health_label.text = "%d" % ceili(current)


func on_health_changed(current: float, maximum: float) -> void:
	_apply_health_ui(current, maximum)


func on_player_died() -> void:
	# 复活时由 Player 发 health_changed，此处仅作预留
	pass


func on_player_hit() -> void:
	if hit_rect != null:
		hit_rect.visible = true
	get_tree().create_timer(0.2).timeout.connect(_hide_hit_rect)


func _hide_hit_rect() -> void:
	if hit_rect != null:
		hit_rect.visible = false


## 来自 Player.Update_Ammo 的中继：更新弹药数字并显示容器
func on_ammo_update(ammo: Array) -> void:
	if ammo_container == null:
		return
	ammo_container.visible = true
	if ammo.size() >= 2:
		if ammo_current_label != null:
			ammo_current_label.text = str(ammo[0])
		if ammo_reserve_label != null:
			ammo_reserve_label.text = str(ammo[1])


func on_enemy_hit() -> void:
	if crosshairhit != null:
		crosshairhit.visible = true
	get_tree().create_timer(0.1).timeout.connect(_hide_crosshair_hit)


func _hide_crosshair_hit() -> void:
	if crosshairhit != null:
		crosshairhit.visible = false


func on_out_of_ammo() -> void:
	if no_more_bullet != null:
		no_more_bullet.text = "No quedan municiones."
	get_tree().create_timer(0.8).timeout.connect(_clear_no_more_bullet)


func on_all_ammo_depleted() -> void:
	if no_more_bullet != null:
		no_more_bullet.text = "弹药耗尽！"
	get_tree().create_timer(1.2).timeout.connect(_clear_no_more_bullet)


func _clear_no_more_bullet() -> void:
	if no_more_bullet != null:
		no_more_bullet.text = ""


func on_switched_to_hand() -> void:
	if ammo_container != null:
		ammo_container.visible = false
