extends CharacterBody3D

## ═══════════════════════════════════════════════════════════════
## Player — 角色控制器（完整脚本）
##
## 【武器流程】
##   默认无武器（徒手）→ 场景中靠近 WorldWeapon 按 interactable
##   → WeaponManager.equip_weapon() 实例化 BaseWeapon + WeaponViewModel
##   → can_shoot = true → 开始射击
##
## 【移动/相机/交互】已移交 MovementComponent、CameraController、InteractionComponent。
## ═══════════════════════════════════════════════════════════════


# ──────────────────────────────────────────────────────────────
#  视角枚举（仅用于身体可见性）
# ──────────────────────────────────────────────────────────────

enum PersonView { FIRST, THIRD }
var current_person: PersonView = PersonView.FIRST


# ──────────────────────────────────────────────────────────────
#  节点引用：第一人称视角链
# ──────────────────────────────────────────────────────────────

@onready var nek:           Node3D            = $firstperson/nek
@onready var head:          Node3D            = $firstperson/nek/head
@onready var eyes:          Node3D            = $firstperson/nek/head/eyes
@onready var de_pie:        CollisionShape3D  = $Stand
@onready var cucilla:       CollisionShape3D  = $Crouch
@onready var raycast3d:     RayCast3D         = $RayCast3D    ## 头顶障碍检测（防止蹲下被卡住）
@onready var player_camera: Camera3D          = $firstperson/nek/head/eyes/Camera3D


# ──────────────────────────────────────────────────────────────
#  节点引用：第三人称视角
# ──────────────────────────────────────────────────────────────

@onready var t_person:      Node3D    = $thirdperson
@onready var third_person:  Camera3D  = $thirdperson/Camera3D
@onready var aimraythird:   RayCast3D = $thirdperson/Camera3D/Aimray
@onready var aimrayendthird: Node3D   = $thirdperson/Camera3D/aimrayend


# ──────────────────────────────────────────────────────────────
#  节点引用：第一人称瞄准射线
# ──────────────────────────────────────────────────────────────

@onready var aimray:    RayCast3D = $firstperson/nek/head/eyes/Camera3D/Aimray
@onready var aimrayend: Node3D    = $firstperson/nek/head/eyes/Camera3D/aimrayend


# ──────────────────────────────────────────────────────────────
#  节点引用：交互 / 捡物
# ──────────────────────────────────────────────────────────────

@onready var interactable_ray: RayCast3D         = $firstperson/nek/head/eyes/Camera3D/Interactable
@onready var pickray:          RayCast3D         = $firstperson/nek/head/eyes/Camera3D/pickray
@onready var holdposition:     Node3D            = $firstperson/nek/head/eyes/Camera3D/HoldPosition
@onready var joint:            Generic6DOFJoint3D = $firstperson/nek/head/eyes/Camera3D/Generic6DOFJoint3D


# ──────────────────────────────────────────────────────────────
#  武器系统（解耦：仅通过 API + 信号交互，不直接持有武器/子弹节点）
#  使用：request_single_shoot / request_auto_shoot / request_reload /
#       switch_to_primary / switch_to_secondary / switch_to_hand /
#       apply_sway / apply_ammo_supply / is_hand；并连接 ammo_changed 等信号。
# ──────────────────────────────────────────────────────────────

@onready var weapon_manager: WeaponManager = $firstperson/nek/head/eyes/Camera3D/Weapon_manager


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

@export var playerStats: Stats
var max_health: float
var health:     float

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


# ═══════════════════════════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# ── 武器系统初始化 ──────────────────────────────────
	weapon_manager.setup(
		self,
		player_camera,
		aimray,
		aimrayend,
		aimraythird,
		aimrayendthird
	)
	weapon_manager.ammo_changed.connect(_on_ammo_changed)
	weapon_manager.weapon_equipped.connect(_on_weapon_equipped)

	# ── 解耦组件初始化（节点路径：InputController, MovementComponent, ...）────
	_setup_components()

	# ── 角色属性与技能 ──────────────────────────────────
	_setup_player_stats()
	_setup_skills()
	SkillManager.skill_used.connect(_on_skill_used)


# ═══════════════════════════════════════════════════════════════
#  输入处理
# ═══════════════════════════════════════════════════════════════

func _setup_components() -> void:
	if not movement_component:
		return
	
	# ─────────────────────────────
	#  1. 运动 / 相机 / 交互组件初始化
	# ─────────────────────────────
	movement_component.setup(
		self,
		input_controller,
		raycast3d,
		de_pie,
		cucilla,
		head,
		animation_tree,
		player_mesh
	)
	camera_controller.setup(
		self,
		nek,
		head,
		eyes,
		player_camera,
		third_person,
		t_person,
		10.0
	)
	interaction_component.setup(
		interactable_ray,
		pickray,
		holdposition,
		joint,
		weapon_manager,
		self
	)
	player_ui_controller.setup(
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
	health_changed.connect(player_ui_controller.on_health_changed)
	player_died.connect(player_ui_controller.on_player_died)
	player_hit.connect(player_ui_controller.on_player_hit)
	self.Update_Ammo.connect(player_ui_controller.on_ammo_update)
	weapon_manager.enemy_hit.connect(player_ui_controller.on_enemy_hit)
	weapon_manager.out_of_ammo.connect(player_ui_controller.on_out_of_ammo)
	weapon_manager.all_ammo_depleted.connect(player_ui_controller.on_all_ammo_depleted)
	weapon_manager.switched_to_hand.connect(player_ui_controller.on_switched_to_hand)
	
	# 初始不显示弹药 UI，等切换到武器时再显示
	Ammo_container.visible = false

func _on_input_mouse_moved(relative: Vector2) -> void:
	if TutorialManager.is_look_allowed():
		var freelook: bool = movement_component.freelook if movement_component else false
		camera_controller.update_look(relative, player_camera.is_current(), freelook)
		weapon_manager.apply_sway(relative)

func _on_change_person_pressed() -> void:
	if player_camera.is_current():
		player_camera.clear_current(true)
	else:
		third_person.clear_current(true)

func _on_input_interact() -> void:
	interaction_component.on_interact_pressed()

func _on_input_throw() -> void:
	interaction_component.on_throw_pressed()

func _on_skill_slot_pressed(slot_index: int) -> void:
	if slot_index == 2:
		SkillManager.use_slot(slot_index, get_player_position())
	else:
		SkillManager.use_slot(slot_index, get_target_position())


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
	if camera_controller and movement_component:
		var input_dir = input_controller.get_move_input() if input_controller else Vector2.ZERO
		camera_controller.update_visual_effects(
			delta, input_dir, movement_component.current_state, movement_component.freelook, is_on_floor()
		)
	if interaction_component:
		interaction_component.update()
	if input_controller and input_controller.is_shoot_held():
		weapon_manager.request_auto_shoot()
	_update_person_view()
	_update_body_visibility()
	if third_person.is_current() and movement_component and movement_component.direction.length_squared() > 0.01:
		if movement_component.current_state in [1, 2]:  # WALKING, SPRINTING
			player_mesh.look_at(-movement_component.direction + global_position, Vector3.UP)


# ═══════════════════════════════════════════════════════════════
#  视角 & 角色模型可见性
# ═══════════════════════════════════════════════════════════════

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
	max_health = playerStats.current_max_health
	health = playerStats.current_max_health
	health_changed.emit(health, max_health)
	playerStats.died.connect(_on_player_died)


## 受到来自敌人的攻击（外部调用）；受击与血量由信号驱动 UI
func take_damage() -> void:
	player_hit.emit()
	damage()


## 扣血（TODO: 接收 AttackData 而非固定 -10）
func damage() -> void:
	health -= 10.0
	if health <= 0.0:
		_on_player_died()
	health_changed.emit(health, max_health)


func apply_healing(amount: int) -> void:
	health = clamp(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)


func _on_player_died() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	player_died.emit()


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

	SkillManager.add_skill(fireball_skill, 1)
	SkillManager.add_to_skill_bar("FireBall", 0)

	SkillManager.add_skill(lightning_skill, 1)
	SkillManager.add_to_skill_bar("Lightning", 1)

	SkillManager.add_skill(groupHealing_skill, 1)
	SkillManager.add_to_skill_bar("Group Healing", 2)


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
