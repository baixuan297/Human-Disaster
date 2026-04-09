extends CharacterBody3D

## ═══════════════════════════════════════════════════════════════
## Player — 角色控制器（完整脚本）
##
## 【武器流程】
##   默认无武器（徒手）→ 场景中靠近 WorldWeapon 按 interactable
##   → WeaponManager.equip_weapon() 实例化 BaseWeapon + WeaponViewModel
##   → can_shoot = true → 开始射击
##   WeaponManager 在自身 _ready 中自绑定相机与瞄准射线，Player 无需 setup 传参。
##
## 【移动/相机/交互】已移交 MovementComponent、CameraController、InteractionComponent。
## 【编排】注入 Movement 的 basis/remap Callable、Camera 节点与 WeaponManager；TP/FP 以 `third_person.is_current()` 为准；路径见 `PlayerViewPaths`。
## ═══════════════════════════════════════════════════════════════


# ──────────────────────────────────────────────────────────────
#  视角枚举（仅用于身体可见性）
# ──────────────────────────────────────────────────────────────

enum PersonView { FIRST, THIRD }
var current_person: PersonView = PersonView.FIRST


# ──────────────────────────────────────────────────────────────
#  节点引用：第一人称视角链（相机架为子场景 CameraRigFP，内含 %FPCamera）
# ──────────────────────────────────────────────────────────────

@onready var nek: Node3D = $firstperson/nek
@onready var head: Node3D = $firstperson/nek/head
@onready var camera_rig_fp: CameraRigFP = $firstperson/nek/head/CameraRigFP
@onready var de_pie: CollisionShape3D = $Stand
@onready var cucilla: CollisionShape3D = $Crouch
@onready var raycast3d: RayCast3D = $RayCast3D    ## 头顶障碍检测（防止蹲下被卡住）
@onready var player_camera: Camera3D = $firstperson/nek/head/CameraRigFP/FPCamera


# ──────────────────────────────────────────────────────────────
#  节点引用：第三人称视角
# ──────────────────────────────────────────────────────────────

@onready var t_person: Node3D = get_node(PlayerViewPaths.THIRD_PERSON_RIG) as Node3D
@onready var third_person: Camera3D = get_node(PlayerViewPaths.THIRD_PERSON_CAMERA) as Camera3D


# ──────────────────────────────────────────────────────────────
#  节点引用：交互 / 捡物
# ──────────────────────────────────────────────────────────────

@onready var interactable_ray: RayCast3D = $firstperson/nek/head/CameraRigFP/FPCamera/Interactable
@onready var pickray: RayCast3D = $firstperson/nek/head/CameraRigFP/FPCamera/pickray
@onready var holdposition: Node3D = $firstperson/nek/head/CameraRigFP/FPCamera/HoldPosition
@onready var joint: Generic6DOFJoint3D = $firstperson/nek/head/CameraRigFP/FPCamera/Generic6DOFJoint3D


# ──────────────────────────────────────────────────────────────
#  武器系统（解耦：仅通过 API + 信号交互，不直接持有武器/子弹节点）
#  使用：request_single_shoot / request_auto_shoot / request_reload /
#       switch_to_primary / switch_to_secondary / switch_to_hand /
#       apply_sway / apply_ammo_supply / is_hand；并连接 ammo_changed 等信号。
# ──────────────────────────────────────────────────────────────

@onready var weapon_manager: WeaponManager = $Weapon_manager


# ──────────────────────────────────────────────────────────────
#  节点引用：角色模型 / 动画
# ──────────────────────────────────────────────────────────────

@onready var armature:       Skeleton3D      = $fishman/Armature/Skeleton3D
@onready var player_mesh:    Node3D          = $fishman
@onready var animation_tree: AnimationTree   = $fishman/AnimationTree


# ──────────────────────────────────────────────────────────────
#  节点引用：UI
# ──────────────────────────────────────────────────────────────

@onready var hit_rect:        ColorRect      = $UI/hitRect
@onready var Ammo_container:  HBoxContainer  = $UI/HBoxContainer
@onready var no_more_bullet:  Label          = $UI/No_more_bullet
@onready var crosshairhit:    TextureRect    = $UI/effects/crosshairhit
@onready var crosshair:       TextureRect    = $UI/effects/crosshair
@onready var health_bar:      ProgressBar    = $UI/healthBar
@onready var health_label:    Label          = $UI/healthLabel


# ──────────────────────────────────────────────────────────────
#  节点引用：场景动画（TODO: 迁移到 InteractionManager）
# ──────────────────────────────────────────────────────────────
# **
#@onready var spacheAni: AnimationPlayer = $"../stage/NavigationRegion3D/spaceship_interior1/AnimationPlayer"


# ──────────────────────────────────────────────────────────────
#  节点引用：技能系统
# ──────────────────────────────────────────────────────────────

#@onready var skill_manager: SkillManager = $SkillManager
# 解耦组件（脚本在 test/；场景中需添加子节点并挂载对应脚本，缺失时仅跳过组件逻辑）
@onready var input_controller: Node = get_node_or_null("InputController")
@onready var movement_component: Node = get_node_or_null("MovementComponent")
@onready var camera_controller: Node = get_node_or_null("CameraController")
@onready var interaction_component: Node = get_node_or_null("InteractionComponent")
@onready var player_ui_controller: Node = get_node_or_null("PlayerUIController")
@onready var movement_audio_component: Node = get_node_or_null("MovementAudioComponent")

@export var fireball_skill:     SkillResource
@export var lightning_skill:    SkillResource
@export var groupHealing_skill: SkillResource


# ──────────────────────────────────────────────────────────────
#  角色属性
# ──────────────────────────────────────────────────────────────

signal player_died
signal health_changed(current: float, maximum: float)
signal player_hit      ## 受击时由 UI 控制器显示 hit_rect
signal Update_Ammo     ## 中继 WeaponManager.ammo_changed 给 UI（保留原信号名）

@export var player_stats: Stats
var max_health: float
var health:     float

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


# ═══════════════════════════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# ── 武器系统：WeaponManager 在子节点 _ready 中已自绑定相机/射线，此处只连信号 ──
	weapon_manager.ammo_changed.connect(_on_ammo_changed)
	weapon_manager.weapon_equipped.connect(_on_weapon_equipped)

	# ── 解耦组件初始化（节点路径：InputController, MovementComponent, ...）────
	_setup_components()

	# ── 角色属性与技能 ──────────────────────────────────
	_setup_player_stats()
	_setup_skills()
	SkillManager.skill_used.connect(_on_skill_used)
	# 从快照或 API 恢复数据（必须在 _setup_player_stats / _setup_skills 之后）
	CharacterDataManager.restore_to_player(self)
	# 临时测试：基因系统链路验证（延迟执行，等待 GameDataManager 加载）
	get_tree().create_timer(1.5).timeout.connect(_test_gene_system, CONNECT_ONE_SHOT)


# ═══════════════════════════════════════════════════════════════
#  输入处理
# ═══════════════════════════════════════════════════════════════

func _get_movement_basis_for_current_person() -> Basis:
	if third_person.is_current():
		return camera_controller.get_third_person_movement_basis()
	return transform.basis


func _remap_move_input_for_person(raw: Vector2) -> Vector2:
	if third_person.is_current():
		return raw
	return Vector2(-raw.x, -raw.y)


func _setup_components() -> void:
	if not movement_component:
		return
	
	# ─────────────────────────────
	#  1. 运动 / 相机 / 交互组件初始化
	# ─────────────────────────────
	movement_component.setup(self, input_controller, raycast3d, de_pie, cucilla, head, animation_tree)
	camera_controller.setup(self, nek, head, camera_rig_fp, third_person, t_person, 10.0, weapon_manager)
	movement_component.external_movement_basis_provider = Callable(self, "_get_movement_basis_for_current_person")
	movement_component.remap_move_input = Callable(self, "_remap_move_input_for_person")
	interaction_component.setup(
		interactable_ray,
		pickray,
		holdposition,
		joint,
		weapon_manager,
		self
	)
	if player_ui_controller != null:
		player_ui_controller.setup(
			$UI,
			health_bar,
			health_label,
			crosshair,
			crosshairhit,
			Ammo_container,
			no_more_bullet,
			hit_rect
		)
	
	# ─────────────────────────────
	#  2. 移动相关音效（脚步 / 落地）
	# ─────────────────────────────
	if movement_audio_component:
		movement_audio_component.setup(movement_component)
	
	# ─────────────────────────────
	#  3. 输入事件绑定
	# ─────────────────────────────
	input_controller.mouse_moved.connect(_on_input_mouse_moved)
	input_controller.change_person_pressed.connect(_on_change_person_pressed)
	input_controller.shoot_pressed.connect(weapon_manager.request_single_shoot)
	input_controller.reload_pressed.connect(weapon_manager.request_reload)
	input_controller.interact_pressed.connect(_on_input_interact)
	input_controller.throw_pressed.connect(_on_input_throw)
	input_controller.skill_slot_pressed.connect(_on_skill_slot_pressed)
	input_controller.change_weapon_primary_pressed.connect(weapon_manager.switch_to_primary)
	input_controller.change_weapon_secondary_pressed.connect(weapon_manager.switch_to_secondary)
	input_controller.change_hand_pressed.connect(weapon_manager.switch_to_hand)
	input_controller.next_weapon_pressed.connect(weapon_manager.switch_to_next)
	input_controller.prev_weapon_pressed.connect(weapon_manager.switch_to_prev)
	
	# ─────────────────────────────
	#  4. UI / 武器事件绑定
	# ─────────────────────────────
	if player_ui_controller != null:
		health_changed.connect(player_ui_controller.on_health_changed)
		player_died.connect(player_ui_controller.on_player_died)
		player_hit.connect(player_ui_controller.on_player_hit)
		self.Update_Ammo.connect(player_ui_controller.on_ammo_update)
		weapon_manager.enemy_hit.connect(player_ui_controller.on_enemy_hit)
		weapon_manager.out_of_ammo.connect(player_ui_controller.on_out_of_ammo)
		weapon_manager.all_ammo_depleted.connect(player_ui_controller.on_all_ammo_depleted)
		weapon_manager.switched_to_hand.connect(player_ui_controller.on_switched_to_hand)
	else:
		push_warning("[Player] PlayerUIController 缺失，HUD（血条等）将不会更新")
	
	# 初始不显示弹药 UI，等切换到武器时再显示
	Ammo_container.visible = false

func _on_input_mouse_moved(relative: Vector2) -> void:
	if not TutorialManager.is_look_allowed():
		return
	var freelook: bool = movement_component.freelook if movement_component else false
	# 必须用「当前激活的相机」分支，勿用「非 FP」推断；否则 FP 仍 is_current 时会同时转身体 + 第三人称架，镜头与角色会乱拧。
	if third_person.is_current():
		camera_controller.update_look(relative, false, freelook)
	elif player_camera.is_current():
		camera_controller.update_look(relative, true, freelook)
	weapon_manager.apply_sway(relative)

func _on_change_person_pressed() -> void:
	if player_camera.is_current():
		third_person.make_current()
	else:
		player_camera.make_current()
		# 切回第一人称时还原模型绕 Y，避免第三人称走路扭身带进 FP
		if player_mesh:
			player_mesh.rotation.y = 0.0

func _on_input_interact() -> void:
	interaction_component.on_interact_pressed()

func _on_input_throw() -> void:
	interaction_component.on_throw_pressed()

func _on_skill_slot_pressed(slot_index: int) -> void:
	var target_pos := get_target_position()
	var target_node := get_target_node()
	if slot_index == 2:
		SkillManager.use_slot(slot_index, get_player_position(), target_node)
	else:
		SkillManager.use_slot(slot_index, target_pos, target_node)


# ═══════════════════════════════════════════════════════════════
#  物理帧（移动/相机/交互/射击由组件处理）
# ═══════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if movement_component:
		movement_component.process(delta)
	else:
		# 未挂组件时仅保证重力与落地，不悬空
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
	if camera_controller:
		var move_in = input_controller.get_move_input() if input_controller else Vector2.ZERO
		if third_person.is_current():
			camera_controller.update_third_person_camera(delta)
		if movement_component:
			camera_controller.update_visual_effects(
				delta, move_in, movement_component.current_state, movement_component.freelook, is_on_floor()
			)
	if interaction_component:
		interaction_component.update()
	if input_controller and input_controller.is_shoot_held():
		weapon_manager.request_auto_shoot()
	_update_person_view()
	_update_body_visibility()
	_apply_third_person_body_face_movement(delta)


# ═══════════════════════════════════════════════════════════════
#  视角 & 角色模型可见性
# ═══════════════════════════════════════════════════════════════

## 战斗锁定：由任务/交互脚本传入敌人等 Node3D；清除时传 null
func set_camera_lock_on_target(target: Node3D) -> void:
	if camera_controller:
		camera_controller.set_lock_on_target(target)


func clear_camera_lock_on_target() -> void:
	if camera_controller:
		camera_controller.clear_lock_on_target()


func _apply_mesh_yaw_world(delta: float, world_yaw: float, sm: float = 10.0) -> void:
	var g := player_mesh.global_rotation
	g.y = lerp_angle(g.y, world_yaw, clampf(delta * sm, 0.0, 1.0))
	player_mesh.global_rotation = g


func _apply_third_person_body_face_movement(delta: float) -> void:
	if not third_person.is_current() or movement_component == null or camera_controller == null or player_mesh == null:
		return
	if camera_controller.has_lock_on_target():
		var tgt: Node3D = camera_controller.get_lock_on_target()
		if tgt != null and is_instance_valid(tgt):
			var p := global_position
			var tp := tgt.global_position
			var dx := tp.x - p.x
			var dz := tp.z - p.z
			if dx * dx + dz * dz > 0.01:
				_apply_mesh_yaw_world(delta, atan2(dx, dz))
		return
	if movement_component.direction.length_squared() < 0.01:
		return
	if movement_component.current_state not in [1, 2]:
		return
	var dir: Vector3 = movement_component.direction
	_apply_mesh_yaw_world(delta, atan2(dir.x, dir.z))


func _update_person_view() -> void:
	current_person = PersonView.FIRST if player_camera.is_current() else PersonView.THIRD


func _update_body_visibility() -> void:
	match current_person:
		PersonView.FIRST:
			armature.visible = weapon_manager.is_hand()
		PersonView.THIRD:
			armature.visible = true


# ═══════════════════════════════════════════════════════════════
#  角色属性 & 血量
# ═══════════════════════════════════════════════════════════════

func _setup_player_stats() -> void:
	player_stats.health_changed.connect(_on_stats_health_changed)
	player_stats.died.connect(_on_player_died)
	if not player_stats.character_level_up.is_connected(_on_player_stats_level_up):
		player_stats.character_level_up.connect(_on_player_stats_level_up)
	GeneManager.genes_changed.connect(player_stats.recalculate_stats)
	health = player_stats.current_health
	max_health = player_stats.current_max_health
	# 初始发送当前值（restore_to_player 之后会再次触发 health_changed）
	health_changed.emit(player_stats.current_health, player_stats.current_max_health)


func _on_stats_health_changed(cur: float, max_val: float) -> void:
	health = cur
	max_health = max_val
	health_changed.emit(cur, max_val)


func _on_player_stats_level_up(new_level: int) -> void:
	GBMssage.show_message("等级提升至 %d" % new_level, "success")


## 读档后恢复武器槽位与弹药（由 CharacterDataManager call_deferred 触发）
func restore_weapon_loadout(loadout: Dictionary) -> void:
	if loadout.is_empty():
		return
	call_deferred("_async_restore_weapon_loadout", loadout)


func _async_restore_weapon_loadout(loadout: Dictionary) -> void:
	if weapon_manager and weapon_manager.has_method("apply_loadout_from_dict"):
		await weapon_manager.apply_loadout_from_dict(loadout)


## 接收 AttackData（技能/武器统一受击接口）
func apply_attack_data(attack_data: AttackData) -> void:
	player_hit.emit()
	player_stats.apply_attack_data(attack_data)


## 受到来自敌人的攻击（支持 AttackData 防御减伤）
func take_damage(attack_data: AttackData = null) -> void:
	player_hit.emit()
	if attack_data == null:
		var fallback := AttackData.new()
		fallback.source = AttackData.AttackType.WEAPON
		fallback.base_damage = 10.0
		fallback.final_damage = maxf(10.0 - player_stats.current_defense, 1.0)
		attack_data = fallback
	player_stats.take_damage(attack_data)


func apply_healing(amount: float) -> void:
	player_stats.heal(amount)


func _on_player_died() -> void:
	health = player_stats.current_max_health
	max_health = player_stats.current_max_health
	health_changed.emit(health, max_health)
	player_died.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if player_stats.character_level_up.is_connected(_on_player_stats_level_up):
			player_stats.character_level_up.disconnect(_on_player_stats_level_up)
		if GeneManager.genes_changed.is_connected(player_stats.recalculate_stats):
			GeneManager.genes_changed.disconnect(player_stats.recalculate_stats)
		CharacterDataManager.snapshot_before_scene_change()
		# viewmodel 容器挂在根 viewport，场景切换时不会自动释放，需显式清理
		if weapon_manager:
			weapon_manager.clear_all_viewmodels()


# ═══════════════════════════════════════════════════════════════
#  WeaponManager 信号回调
# ═══════════════════════════════════════════════════════════════

## 弹药变化 → 中继给 UI（Update_Ammo 供 playerAmmoUi 更新数字）；并保证弹药栏可见
func _on_ammo_changed(Current_Ammo: int, Reserve_Ammo: int) -> void:
	Ammo_container.visible = true
	Update_Ammo.emit([Current_Ammo, Reserve_Ammo])


## 武器装备成功（可在此更新武器名称 UI、稀有度颜色等）
func _on_weapon_equipped(data: WeaponData, slot: int) -> void:
	print("装备武器: [%s] → 槽位 %d" % [data.Weapon_name, slot])


# WeaponManager.weapon_equipped 后 ammo_changed 信号会自动触发弹药栏显示
# 因此 _on_weapon_equipped 不需要手动 Ammo_container.visible = true


# ═══════════════════════════════════════════════════════════════
#  技能系统
# ═══════════════════════════════════════════════════════════════

func _setup_skills() -> void:
	SkillManager.character = self
	# 未登录时用 Export 默认技能；restore_to_player 会覆盖
	if UserManager.current_character_id.is_empty():
		if fireball_skill:
			SkillManager.add_skill(fireball_skill, 1)
			SkillManager.add_to_skill_bar("FireBall", 0)
		if lightning_skill:
			SkillManager.add_skill(lightning_skill, 1)
			SkillManager.add_to_skill_bar("Lightning", 1)
		if groupHealing_skill:
			SkillManager.add_skill(groupHealing_skill, 1)
			SkillManager.add_to_skill_bar("Group Healing", 2)


## 临时测试：验证基因系统链路（猛禽视觉 2001001 提升暴击率）
func _test_gene_system() -> void:
	const GENE_ID := 2001001  # 猛禽视觉（与 game_data/genes.json 7 位 ID 一致）
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🧬 [基因测试] 开始验证基因系统链路")

	# 1. 前置检查：基因定义是否已加载
	var def := GeneManager.get_gene_def(GENE_ID)
	if def == null:
		print("   ⚠️ 基因 %d 定义未加载（GameDataManager 可能尚未就绪），跳过测试" % GENE_ID)
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		return

	# 2. 设置职业与点数，记录基础暴击率
	GeneManager.setup("Predator Striker", 100)
	var base_crit := player_stats.base_critical_rate

	# 3. 解锁（若已从快照恢复则跳过）并激活
	if not GeneManager.has_gene(GENE_ID):
		if not GeneManager.unlock_gene(GENE_ID):
			print("   ❌ 解锁基因 %d 失败" % GENE_ID)
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			return
	if not GeneManager.activate_gene(GENE_ID):
		print("   ❌ 激活基因 %d 失败（可能槽位已满）" % GENE_ID)
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		return

	# 4. 验证 Stats 已更新（genes_changed → recalculate_stats）
	var crit_after := player_stats.current_critical_rate
	var bonuses := GeneManager.get_bonuses()

	print("   ✅ 基因: %s (ID=%d)" % [def.gene_name, GENE_ID])
	print("   📊 暴击率: base=%.2f%% → current=%.2f%%" % [base_crit * 100, crit_after * 100])
	print("   📊 暴击倍率: %.2f" % player_stats.current_critical_damage)
	print("   📊 闪避率: %.2f%%" % (player_stats.current_evasion * 100))
	print("   📊 激活基因数: %d / %d" % [GeneManager.get_active_count(), GeneManager.get_slot_limit()])
	if bonuses.get("crit_rate_bonus", 0.0) != 0.0 or bonuses.get("crit_rate", 0.0) != 0.0:
		print("   📊 基因暴击加成: +%.2f%%" % ((bonuses.get("crit_rate_bonus", 0.0) + bonuses.get("crit_rate", 0.0)) * 100))

	# 5. 快速暴击模拟（100 次判定）
	var crit_hits := 0
	for i in 100:
		if player_stats.roll_critical():
			crit_hits += 1
	print("   🎲 暴击模拟(100次): %d 次暴击 (期望约 %.0f)" % [crit_hits, crit_after * 100])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


func upgrade_skill(skill_name: String) -> void:
	if SkillManager.level_up_skill(skill_name):
		print("技能升级: %s" % skill_name)


func learn_skill(skill_res: SkillResource, slot_index: int = -1) -> void:
	SkillManager.add_skill(skill_res, 1)
	if slot_index >= 0:
		SkillManager.add_to_skill_bar(skill_res.skill_name, slot_index)


func get_skill_cooldowns() -> Array:
	var cooldowns := []
	for info in SkillManager.get_skill_bar_info():
		if info.is_empty():
			cooldowns.append(null)
		else:
			cooldowns.append({
				"name":      info.get("name", ""),
				"remaining": info.get("cooldown_remaining", 0.0),
				"total":     info.get("cooldown", 1.0),
				"progress":  info.get("cooldown_remaining", 0.0) / info.get("cooldown", 1.0),
			})
	return cooldowns


## 获取鼠标指向的碰撞体（DOT/DEBUFF/INSTANT 技能需要 target_node）
## 若命中 Area3D（部位），向上查找持有 stats 的根节点
func get_target_node() -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result or not result.has("collider"):
		return null
	var coll = result["collider"]
	if coll is Node3D:
		var n: Node = coll
		while n:
			if n.get("stats") != null or n.get("player_stats") != null:
				return n as Node3D
			n = n.get_parent()
		return coll as Node3D
	return null


## 获取鼠标指向的世界坐标（技能目标 / 瞄准用）
func get_target_position() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return global_position + global_transform.basis.z * 100.0

	var mouse_pos := get_viewport().get_mouse_position()
	var from      := camera.project_ray_origin(mouse_pos)
	var to        := from + camera.project_ray_normal(mouse_pos) * 1000.0

	var query  := PhysicsRayQueryParameters3D.create(from, to)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result["position"] if result else global_position + global_transform.basis.z * 100.0


func get_player_position() -> Vector3:
	return global_position


func _on_skill_used(skill: Skill) -> void:
	print("使用技能: %s (冷却: %.1fs)" % [skill.skill_resource.skill_name, skill.cooldown_remaining])
	# TODO: 施法动画 / 消耗法力 / 更新 UI
