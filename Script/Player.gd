extends CharacterBody3D

## 角色运动和视角
# first person node
@onready var nek: Node3D = $firstperson/nek
@onready var head: Node3D = $firstperson/nek/head
@onready var eyes: Node3D = $firstperson/nek/head/eyes
@onready var de_pie: CollisionShape3D = $Stand
@onready var cucilla: CollisionShape3D = $Crouch
@onready var raycast3d: RayCast3D = $RayCast3D
@onready var player_camera: Camera3D = $firstperson/nek/head/eyes/Camera3D

# third person node
@onready var t_person: Node3D = $thirdperson
@onready var third_person: Camera3D = $thirdperson/Camera3D
# 角色模型
@onready var armature: Skeleton3D = $fishman/Armature/Skeleton3D
# 角色节点
@onready var player: Node3D = $fishman
# 角色受击特效
@onready var hit_rect: ColorRect = $hitRect
# 动画和动画树
@onready var animation_player: AnimationPlayer = $fishman/AnimationPlayer
@onready var animation_tree: AnimationTree = $fishman/AnimationTree

## 角色视角
enum persons {FIRST, THIRD}
var current_person: persons = persons.FIRST

## 第三人称视角
# **
var yaw: float = 0.0
var pitch: float = 0.0
# 灵敏度
var sense_hori: float = 0.15
var sense_vert: float = 0.15
# 鼠标速度
const t_speed_mouse: float = 0.1

## 第一人称视角
# 角色控制速度
var SPEED_Normal: float = 5.0
const JUMP_VELOCITY: float = 7.0
const speed_walk: float = 5.0
const speed_run: float = 8.0
const speed_crouch: float = 2.0
const speed_mouse: float = 0.1

# 受击后后退
const hit_stagger: float = 8.0

# 线性速度
var air_lerp: float = 3.0
var speed_lerp: float = 10.0
var direction: Vector3 = Vector3.ZERO

# var free_look_amount = 5
# **
# 滑行
var slide_timer: float = 1
var slide_time_max: float = 1.0
var slide_vector = Vector2.ZERO
var slide_speed: float = 10.0

## 头部运动
# 速度
const move_sprint = 22.0
const move_walk = 15.0
const move_crouch = 10.0
# 强度
const move_sprint_intensity = 0.2
const move_walk_intensity = 0.1
const move_crouch_intensyty = 0.05
# 向量
var head_move_vector = Vector2.ZERO
# 时间索引
var head_move_index = 0.0
# 状态值 （实时跟踪头部运动的当前位置或强度）
var head_move_current = 0.0
# 高度
const altura_head = 1.0

## 状态机
# TODO: State Machine
var walking: bool = false
var freelook: bool = false
var crouching: bool = false
var sprinting: bool = false
var sliding: bool = false
var moving: bool = false
var jumping: bool = false
# 角色状态动画
# **
enum {IDLE, WALK, RUN, CROUCH, JUMP}
var CurrentAni = IDLE

## Weapon
# Pistol
@onready var gun_ani: AnimationPlayer = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/PistolSubView/SubViewport/model_camara_pistol/rig/gun/AnimationPlayer
@onready var gun_barrel: RayCast3D = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/PistolSubView/SubViewport/model_camara_pistol/rig/gun/pistol/muzzle_ray
# MP7
@onready var mp7ani: AnimationPlayer = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/MP7SubView/SubViewport/model_camara_mp7/rig/gun/AnimationPlayer
@onready var mp7_barrel = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/MP7SubView/SubViewport/model_camara_mp7/rig/gun/mp7/meshes/barrel
# aim ray
@onready var aimray: RayCast3D = $firstperson/nek/head/eyes/Camera3D/Aimray
@onready var aimraythird: RayCast3D = $thirdperson/Camera3D/Aimray
@onready var aimrayend: Node3D = $firstperson/nek/head/eyes/Camera3D/aimrayend
@onready var aimrayendthird: Node3D = $thirdperson/Camera3D/aimrayend
# ammo apply point
@onready var interactable_ray: RayCast3D = $firstperson/nek/head/eyes/Camera3D/Interactable
# View Model
@onready var mp7_model_view_camera = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/MP7SubView/SubViewport/model_camara_mp7
@onready var pistol_model_view_camera = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/PistolSubView/SubViewport/model_camara_pistol
# ammo, reload ammo
@onready var Ammo_container: HBoxContainer = $UI/HBoxContainer
@onready var no_more_bullet: Label = $UI/No_more_bullet
# crosshair
@onready var crosshairhit: TextureRect = $UI/effects/crosshairhit
@onready var crosshair: TextureRect = $UI/effects/crosshair


# 玩家被攻击信号
#signal player_hit
# 换弹信号
signal Update_Ammo

# 武器资源
@export var _weapon_resource : Array[WeaponData]

# 当前子弹
var current_ammo = ""
var reserve_ammo = ""
var wealist = {}

# 武器子弹
var instance: Node3D
var bullet = preload("res://blender/gun/bullet.tscn")
var bullettrail = preload("res://blender/gun/bullettrail.tscn")

# 武器切换
# **
enum weapons {
	MP7,
	PISTOL,
	HAND,
}
# 当前武器
var weapon = weapons.HAND
# 是否允许射击
var can_shoot = true

## 抓取物品
@onready var pickray = $firstperson/nek/head/eyes/Camera3D/pickray
@onready var holdposition = $firstperson/nek/head/eyes/Camera3D/HoldPosition
@onready var joint = $firstperson/nek/head/eyes/Camera3D/Generic6DOFJoint3D
@onready var staticbody = $firstperson/nek/head/eyes/Camera3D/StaticBody3D
# 拿起的物品记录
var pick_object : Object
var rotation_power = 0.05

# 场景动画 **
@onready var spacheAni = $"../stage/NavigationRegion3D/spaceship_interior1/AnimationPlayer"

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

#var pistol_scene: PackedScene = preload("res://blender/gun/gun.tscn")
#var weaponManager: WeaponManager

## 角色属性
signal player_died
# UI
@onready var health_bar: ProgressBar = $UI/healthBar
@onready var health_label: Label = $UI/healthLabel
# 角色属性资源
@export var playerStats: Stats
var max_health: float 
var health: float


## 技能
@onready var skill_manager: SkillManager = $SkillManager

@export var fireball_skill: SkillResource


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# set vieport position and size
	$firstperson/nek/head/eyes/Camera3D/Weapon_manager/MP7SubView/SubViewport.size = DisplayServer.window_get_size()
	$firstperson/nek/head/eyes/Camera3D/Weapon_manager/PistolSubView/SubViewport.size = DisplayServer.window_get_size()
	# 多人游戏同步
	# $MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
	
	#weaponManager = WeaponManager
	
	setup_player_stats()
	
	# 技能
	skill_manager.character = self
	skill_manager.add_skill(fireball_skill, 1)
	skill_manager.add_to_skill_bar("FireBall", 0)
	
	skill_manager.skill_used.connect(_on_skill_used)


## 获取目标位置（示例：使用鼠标光线投射）
func get_target_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return global_position + global_transform.basis.z * 100
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		return result["position"]
	else:
		# 默认返回前方位置
		return global_position + global_transform.basis.z * 100
		

## 技能使用回调
func _on_skill_used(skill: Skill):
	var info = skill.get_info()
	print("使用技能: ", info["name"], " 等级: ", info["level"])
	print("  伤害: ", info["damage"])
	print("  冷却时间: ", info["cooldown"], "秒")


func _input(event):	
	if event is InputEventMouseMotion:
		#moving = Input.is_action_pressed("move_right") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_back") or Input.is_action_pressed("move_forward")
		# first
		if freelook and player_camera.is_current():
			nek.rotate_y(deg_to_rad(-event.relative.x * speed_mouse))
			nek.rotation.y = clamp(nek.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		else:
			if player_camera.is_current():
				rotate_y(deg_to_rad(-event.relative.x * speed_mouse))
		if player_camera.is_current():
			head.rotate_x(deg_to_rad(event.relative.y * speed_mouse))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-60), deg_to_rad(60))
		# third
		if third_person.is_current():
			rotate_y(deg_to_rad(-event.relative.x * sense_hori))
			
			#yaw = clamp(yaw - event.relative.x * sense_hori, -360, 360)
			pitch = clamp(pitch - event.relative.y * sense_vert, -50, 50)
			#t_person.rotation.y = deg_to_rad(yaw)
			t_person.rotation.x = deg_to_rad(pitch)
		
		# mp7_model_view sway
		mp7_model_view_camera.sway(Vector2(event.relative.x, event.relative.y))
		pistol_model_view_camera.sway(Vector2(event.relative.x, event.relative.y))
		
	# chage person
	if event.is_action_pressed("change_person"):
		if player_camera.is_current():
			player_camera.clear_current(true)
		else:
			third_person.clear_current(true)

	# shoot
	if Input.is_action_just_pressed("shoot"):
		if can_shoot:
			match weapon:
				weapons.PISTOL:
					_shoot_pistols()
					# **
					#weaponManager.attack(self)
					
					weapon_ammo(weapons.PISTOL)
	if Input.is_action_pressed("shoot"):
		# pick up object
		if pick_object == null:
			pickup_object()
		elif pick_object != null:
			remove_object()
	
	if Input.is_action_just_pressed("reload"):
		match weapon:
			weapons.MP7:
				can_shoot = false
				reload_ammo(weapons.MP7)
				can_shoot = true
			weapons.PISTOL:
				can_shoot = false
				reload_ammo(weapons.PISTOL)
				can_shoot = true
	
	if Input.is_action_just_pressed("interactable") and interactable_ray.get_collider() is Interactable:
		var collider = interactable_ray.get_collider()
		if collider.is_in_group("ammo_apply_point"):
			match weapon:
				weapons.MP7:
					Ammo_apply_point(weapons.MP7)
				weapons.PISTOL:
					Ammo_apply_point(weapons.PISTOL)
		# **
		if collider.is_in_group("machine"):
			health = max_health
			_update_health_stat()
		
		# space ship open the door
		# 打算使用position的方式来实现批量开关门，不行就一个一个来。
		if collider.is_in_group('door1'):
			spacheAni.play("Opendoor1")
			await get_tree().create_timer(8.0).timeout
			spacheAni.play_backwards("Opendoor1")
		elif collider.is_in_group('door2'):
			spacheAni.play("Opendoor2")
			await get_tree().create_timer(8.0).timeout
			spacheAni.play_backwards("Opendoor2")
		elif collider.is_in_group('door3'):
			spacheAni.play("Opendoor3")
			await get_tree().create_timer(8.0).timeout
			spacheAni.play_backwards("Opendoor3")
		
		# ** 这一片都得重做应该使用个管理器进行管理
		if collider.is_in_group("chest"):
			var inventory = InventoryManager
			inventory.add_item_by_numeric_id(201, 1) # x87
			inventory.add_item_by_numeric_id(202, 1) # 手枪
			inventory.add_item_by_numeric_id(203, 1) # 冲锋枪
			inventory.add_item_by_numeric_id(251, 99) # 能量弹
			inventory.add_item_by_numeric_id(252, 999) # 30mm
			inventory.add_item_by_numeric_id(253, 99) # 9mm
			inventory.add_item_by_numeric_id(101, 3)  # 门禁卡
			inventory.add_item_by_numeric_id(102, 99999)  # 星币
			inventory.add_item_by_numeric_id(103, 1)  # 改名卡
			inventory.add_item_by_numeric_id(100, 1)  # 实验室钥匙
				
	# throw objectw
	if Input.is_action_pressed("rightclick"):
		if pick_object != null:
			var knockback = pick_object.global_position - global_position
			pick_object.apply_central_impulse(knockback * 2)
			remove_object()
	
	# Skill System
	if Input.is_action_just_pressed("Skill1"):
		var target_pos = get_target_position()
		skill_manager.use_skill_from_bar(0, target_pos)
		


func _physics_process(delta):
	# 多人游戏
	#if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
	
	
	handle_animation()
	# 更新武器视角
	update_weapon_camera_transform()
	
	# 应用重力
	apply_gravity(delta)
	# 获取玩家的移动输入向量（方向输入）
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# 状态管理 (下蹲、跑步、滑铲)
	handle_movement_state(input_dir, delta)
	
	# 视觉效果 (头部晃动和自由视角)
	handle_visual_effects(input_dir, delta)
	
	# 应用速度
	apply_final_velocity_and_animation(input_dir, delta)
	move_and_slide()
	
	# 武器切换、捡起物体等
	handle_object_pickup()
	handle_weapon_input()
	
	# 切换视角
	_change_person()
	
	_body_switch()
	
	
	#
	#handle_animation()
	#var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	#
	## mp7_model_view transform
	#mp7_model_view_camera.global_transform = player_camera.global_transform
	#pistol_model_view_camera.global_transform = player_camera.global_transform
	#
	## Pulsa alguno teclado
	## crouch
	#if Input.is_action_pressed("crouch") || sliding:
		#SPEED_Normal = lerp(SPEED_Normal, speed_crouch, delta * speed_lerp)
		#head.position.y = lerp(head.position.y, -1.6 + altura_head, delta * speed_lerp)
		#de_pie.disabled = true
		#cucilla.disabled = false
		#
		## slide start logic
		#if sprinting && input_dir != Vector2.ZERO:
			#sliding = true
			#slide_timer = slide_time_max 
			#slide_vector = input_dir
			#freelook = true
		#
		#walking = false
		#crouching = true
		#sprinting = false
		#jumping = false
	#elif !raycast3d.is_colliding():
		#de_pie.disabled = false
		#cucilla.disabled = true
		#head.position.y = lerp(head.position.y, 0.0, delta * speed_lerp)
		#if Input.is_action_pressed("Run") and Input.is_action_pressed("move_forward"):
			#SPEED_Normal = lerp(SPEED_Normal, speed_run, delta * speed_lerp)
			#walking = true
			#crouching = false
			#sprinting = true
			#jumping = false
		#elif not input_dir:
			#walking = false
			#sprinting = false
			#crouching = false
		#else:
			#SPEED_Normal = lerp(SPEED_Normal, speed_walk, delta * speed_lerp)
			#walking = true
			#crouching = false
			#sprinting = false
			#jumping = false
		#if Input.is_action_just_pressed("jump") and is_on_floor():
			#velocity.y = JUMP_VELOCITY
			#sliding = false
			#jumping = true
			#jump()
#
	## free look
	#if Input.is_action_pressed("free_look") || sliding:
		#freelook = true
	#else:
		#freelook = false
		#nek.rotation.y = lerp(nek.rotation.y, 0.0, delta * speed_lerp)
		#
	#if sliding:
		#slide_timer -= delta
		#if slide_timer <= 0.0:
			#sliding = false
			##slide_timer = false
			#freelook = false
#
	## head bobbing
	#if sprinting:
		#head_move_current = move_sprint_intensity
		#head_move_index += move_sprint*delta
	#elif walking and !sprinting:
		#head_move_current = move_walk_intensity
		#head_move_index += move_walk*delta
	#else:
		#head_move_current = move_crouch_intensyty
		#head_move_index += move_crouch*delta
#
	#if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		## 摇头晃脑
		#head_move_vector.y = sin(head_move_index)
		#head_move_vector.x = sin(head_move_index/2) + 0.5
#
		#eyes.position.y = lerp(eyes.position.y, head_move_vector.y * (head_move_current/2.0), delta * speed_lerp)
		#eyes.position.x = lerp(eyes.position.x, head_move_vector.x * head_move_current, delta * speed_lerp)
	#else:
		#eyes.position.y = lerp(eyes.position.y, 0.0, delta * speed_lerp)
		##eyes.position.x = lerp(eyes.position.y, 0.0, delta * speed_lerp)
		#eyes.position.x = lerp(eyes.position.x, 0.0, delta * speed_lerp)
#
	## Add the gravity.
	#if not is_on_floor():
		#velocity.y -= gravity * delta
#
	#if is_on_floor():
		#direction = lerp(direction, (transform.basis * Vector3(-input_dir.x, 0.0, -input_dir.y)).normalized(), delta * speed_lerp)
	#else:
		#if input_dir != Vector2.ZERO:
			#direction = lerp(direction, (transform.basis * Vector3(-input_dir.x, 0.0, -input_dir.y)).normalized(), delta * air_lerp)
#
	#if sliding:
		#direction = (transform.basis * Vector3(slide_vector.x,0.0,slide_vector.y)).normalized()
		#SPEED_Normal = slide_timer * slide_speed
#
	#if direction:
		#if is_on_floor() and sprinting and walking:
			#CurrentAni = RUN
			#if third_person.is_current():
				#player.look_at(-direction + position, Vector3.UP)
		#elif walking:
			#CurrentAni = WALK
			#if third_person.is_current():
				#player.look_at(-direction + position, Vector3.UP)
		#elif crouching:
			#CurrentAni = CROUCH
		#else:
			#CurrentAni = IDLE
#
#
		#velocity.x = direction.x * SPEED_Normal
		#velocity.z = direction.z * SPEED_Normal
#
	#else:
		#if is_on_floor() and !crouching:
			#CurrentAni = IDLE
#
		#velocity.x = move_toward(velocity.x, 0, SPEED_Normal)
		#velocity.z = move_toward(velocity.z, 0, SPEED_Normal)
#
	## pick object
	#if pick_object != null:
		#var a = pick_object.global_transform.origin
		#var b = holdposition.global_transform.origin
		#pick_object.set_linear_velocity((b-a) * 10)
#
	## weapon switch
	#if Input.is_action_just_pressed("change_weapon1") and weapon != weapons.MP7:
		#_raise_weapon(weapons.MP7)
		#weapon_ammo(weapons.MP7)
		#await get_tree().create_timer(0.4).timeout
		#pistol_model_view_camera.visible = false
		#mp7_model_view_camera.visible = true
		#Ammo_container.visible = true
	#if Input.is_action_just_pressed("change_weapon2") and weapon != weapons.PISTOL:
		## **
		##weaponManager.equip_weapon(pistol_scene, _weapon_resource.get(1))
		#
		#_raise_weapon(weapons.PISTOL)
		#weapon_ammo(weapons.PISTOL)
		#
		#mp7_model_view_camera.visible = false
		#pistol_model_view_camera.visible = true
		#Ammo_container.visible = true
	#if Input.is_action_just_pressed("change_hand"):
		#weapon = weapons.HAND
		#Ammo_container.visible = false
		#pistol_model_view_camera.visible = false
		#mp7_model_view_camera.visible = false
		#can_shoot = false
			#
	## 让mp7可以单按一直射 **
	#if Input.is_action_pressed("shoot"):
		#if can_shoot:
			#match weapon:
				#weapons.MP7:
					#_auto_shot()
					#weapon_ammo(weapons.MP7)
	#
	#_change_person()
	#_body_switch()
	#move_and_slide()


func update_weapon_camera_transform():
	# 将武器模型的视角与主相机视角同步
	mp7_model_view_camera.global_transform = player_camera.global_transform
	pistol_model_view_camera.global_transform = player_camera.global_transform


func apply_gravity(delta):
	# 添加重力。只有当不在地面上时才应用。
	if not is_on_floor():
		velocity.y -= gravity * delta


func handle_movement_state(input_dir: Vector2, delta: float):
	# 处理滑铲计时器和退出滑铲状态
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			sliding = false # 修正：将布尔值赋给滑动状态，而非计时器本身
			freelook = false # 退出滑铲时关闭自由视角
	
	# --- 状态优先级判断：下蹲/滑铲 > 站立/奔跑 ---
	
	if Input.is_action_pressed("crouch") or sliding:
		# 进入或维持下蹲状态
		enter_crouch_state(input_dir, delta)
	
	elif not raycast3d.is_colliding(): # 检查上方是否被阻挡 (避免下蹲被卡住)
		# 进入站立/奔跑/走路状态
		enter_stand_state(input_dir, delta)
		
	# 处理跳跃逻辑
	if not crouching and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sliding = false
		jumping = true
		jump()


func enter_crouch_state(input_dir, delta):
	# 速度平滑过渡到下蹲速度
	SPEED_Normal = lerp(SPEED_Normal, speed_crouch, delta * speed_lerp)
	# 头部平滑过渡到下蹲高度
	head.position.y = lerp(head.position.y, -1.6 + altura_head, delta * speed_lerp)
	
	# 更新碰撞体/相机
	de_pie.disabled = true
	cucilla.disabled = false
	
	# 滑铲启动逻辑：奔跑时按下蹲
	if sprinting and input_dir != Vector2.ZERO and not sliding:
		sliding = true
		slide_timer = slide_time_max
		slide_vector = input_dir
		freelook = true
	
	# 更新状态标志
	walking = false
	crouching = true
	sprinting = false
	jumping = false


func enter_stand_state(input_dir, delta):
	# 碰撞体恢复
	de_pie.disabled = false
	cucilla.disabled = true
	# 头部平滑恢复到站立高度
	head.position.y = lerp(head.position.y, 0.0, delta * speed_lerp)
	
	if input_dir == Vector2.ZERO:
		# 静止状态
		walking = false
		sprinting = false
		crouching = false
	elif Input.is_action_pressed("Run") and Input.is_action_pressed("move_forward"):
		# 奔跑状态
		SPEED_Normal = lerp(SPEED_Normal, speed_run, delta * speed_lerp)
		walking = true
		crouching = false
		sprinting = true
	else:
		# 走路状态
		SPEED_Normal = lerp(SPEED_Normal, speed_walk, delta * speed_lerp)
		walking = true
		crouching = false
		sprinting = false
	jumping = false


func handle_visual_effects(input_dir, delta):
	# 自由视角 (Free Look)
	if Input.is_action_pressed("free_look") or sliding:
		freelook = true
	else:
		freelook = false
		# 平滑恢复颈部/相机到中央
		nek.rotation.y = lerp(nek.rotation.y, 0.0, delta * speed_lerp)

	# 头部晃动 (Head Bobbing)
	var move_intensity = 0.0
	var move_speed = 0.0
	
	# 根据当前状态设置晃动参数
	if sprinting:
		move_intensity = move_sprint_intensity
		move_speed = move_sprint
	elif walking:
		move_intensity = move_walk_intensity
		move_speed = move_walk
	else: # 静止或蹲伏
		move_intensity = move_crouch_intensyty # 原代码逻辑，即使静止也有轻微晃动
		move_speed = move_crouch
	
	head_move_index += move_speed * delta

	if is_on_floor() and not sliding and input_dir != Vector2.ZERO:
		# 只有在地面上且移动时才进行晃动计算
		head_move_vector.y = sin(head_move_index)
		head_move_vector.x = sin(head_move_index/2) + 0.5

		eyes.position.y = lerp(eyes.position.y, head_move_vector.y * (move_intensity/2.0), delta * speed_lerp)
		# 修正笔误: 第二个参数应使用 x 位置，而非 y 位置
		eyes.position.x = lerp(eyes.position.x, head_move_vector.x * move_intensity, delta * speed_lerp)
	else:
		# 停止移动时，平滑恢复到原点
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * speed_lerp)
		# 修正笔误: 第二个参数应使用 x 位置，而非 y 位置
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * speed_lerp)


func apply_final_velocity_and_animation(input_dir, delta):
	var target_dir = Vector3.ZERO
	
	# 1. 计算目标方向
	if is_on_floor():
		# 在地面上时，平滑过渡方向
		target_dir = (transform.basis * Vector3(-input_dir.x, 0.0, -input_dir.y)).normalized()
		direction = lerp(direction, target_dir, delta * speed_lerp)
	elif input_dir != Vector2.ZERO:
		# 在空中时，使用更小的 lerp 值模拟空气控制
		target_dir = (transform.basis * Vector3(-input_dir.x, 0.0, -input_dir.y)).normalized()
		direction = lerp(direction, target_dir, delta * air_lerp)

	# 2. 滑铲特殊处理：覆盖方向和速度
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x,0.0,slide_vector.y)).normalized()
		SPEED_Normal = slide_timer * slide_speed # 速度随时间衰减

	# 3. 应用速度和设置动画
	if direction.length_squared() > 0.01: # 检查是否有移动方向
		# 根据状态设置动画
		if is_on_floor() and sprinting and walking:
			CurrentAni = RUN
		elif walking:
			CurrentAni = WALK
		elif crouching:
			CurrentAni = CROUCH
		else:
			CurrentAni = IDLE

		# 应用速度
		velocity.x = direction.x * SPEED_Normal
		velocity.z = direction.z * SPEED_Normal
		
		# 仅在第三人称模式且移动时旋转角色
		if (CurrentAni == RUN or CurrentAni == WALK) and third_person.is_current():
			player.look_at(-direction + position, Vector3.UP)
	else:
		# 没有输入时，减速归零
		if is_on_floor() and not crouching:
			CurrentAni = IDLE
		velocity.x = move_toward(velocity.x, 0, SPEED_Normal)
		velocity.z = move_toward(velocity.z, 0, SPEED_Normal)


func handle_object_pickup():
	# 捡起物体逻辑
	if pick_object != null:
		var a = pick_object.global_transform.origin
		var b = holdposition.global_transform.origin
		# 使用设置线性速度的方式平滑移动物体
		pick_object.set_linear_velocity((b - a) * 10)


func handle_weapon_input():
	# 武器切换逻辑 (使用 match 语句可以更清晰)
	if Input.is_action_just_pressed("change_weapon1") and weapon != weapons.MP7:
		switch_weapon(weapons.MP7)
	elif Input.is_action_just_pressed("change_weapon2") and weapon != weapons.PISTOL:
		switch_weapon(weapons.PISTOL)
	elif Input.is_action_just_pressed("change_hand"):
		weapon = weapons.HAND
		Ammo_container.visible = false
		pistol_model_view_camera.visible = false
		mp7_model_view_camera.visible = false
		can_shoot = false
			
	# 连射逻辑 (仅限按下时触发)
	if Input.is_action_pressed("shoot") and can_shoot:
		match weapon:
			weapons.MP7:
				_auto_shot()
				weapon_ammo(weapons.MP7)


func switch_weapon(new_weapon):
	# 统一的换枪流程
	_raise_weapon(new_weapon)
	weapon_ammo(new_weapon)
	
	# 等待一个短时间 (通常是动画时间)
	await get_tree().create_timer(0.4).timeout
	
	# 切换模型可见性
	pistol_model_view_camera.visible = (new_weapon == weapons.PISTOL)
	mp7_model_view_camera.visible = (new_weapon == weapons.MP7)
	Ammo_container.visible = true


func _change_person():
	if player_camera.is_current():
		current_person = persons.FIRST
	else:
		current_person = persons.THIRD


func _body_switch():
	# its for hide player body, if we have pick weapon
	match current_person:
		persons.FIRST:
			match weapon:
				weapons.MP7:
					armature.visible = false
				weapons.PISTOL:
					armature.visible = false
				weapons.HAND:
					armature.visible = true
		persons.THIRD:
			armature.visible = true


func _shoot_pistols():
	if wealist.get("PISTOL").Current_Ammo != 0:
		if !gun_ani.is_playing():
			gun_ani.play("fire")
			# **
			instance = bullet.instantiate()
			instance.position = gun_barrel.global_position
			#instance.global_transform = gun_barrel.global_transform
			get_parent().add_child(instance)
			if player_camera.is_current():
				get_aim_target(persons.FIRST)
			if third_person.is_current():
				get_aim_target(persons.THIRD)
			
			wealist.get("PISTOL").Current_Ammo -= 1
	elif wealist.get("PISTOL").Current_Ammo == 0: #**
		reload_ammo(weapons.PISTOL)
	else:
		reload_ammo(weapons.PISTOL)


func _auto_shot():
	if !mp7ani.is_playing():
		if wealist.get("MP7").Current_Ammo != 0:
				mp7ani.play("fire")
				instance = bullettrail.instantiate()
				if player_camera.is_current():
					mp7_aimray(persons.FIRST)
				if third_person.is_current():
					mp7_aimray(persons.THIRD)
				wealist.get("MP7").Current_Ammo -= 1
				#emit_signal("Update_Ammo", [current_ammo, reserve_ammo])
		else:
				reload_ammo(weapons.MP7)


# bullet aim ray function
func mp7_aimray(person):
	match person:
		persons.FIRST:
			if aimray.is_colliding():
				instance.init(mp7_barrel.global_position, aimray.get_collision_point())
				get_parent().add_child(instance)
				if aimray.get_collider().is_in_group("enemy"):
					# **
					var attackData := AttackData.new()
					attackData.source = AttackData.AttackType.WEAPON
					attackData.weapon_data = _weapon_resource[0]
					#attack.body_part_multiplier = 2.0
					aimray.get_collider().enemy_hit(attackData)
					#aimray.get_collider().stats.take_damage(attackData)
					_on_enemy_hit() # **
					instance.trriger_particles(aimray.get_collision_point(), mp7_barrel.global_position, true)
				else:
					instance.trriger_particles(aimray.get_collision_point(), mp7_barrel.global_position, false)
				# rigi发射**
				var collider = aimray.get_collider()
				if collider.is_in_group("moveObject"):
					# 获取Ray的方向
					var ray_direction = -aimray.global_transform.basis.z.normalized()

					# 反向推力
					var push_direction = ray_direction

					# 冲击力度
					var force = push_direction * 5.0
					collider.apply_central_impulse(force)
				
			else:
				instance.init(mp7_barrel.global_position, aimrayend.global_position)
				get_parent().add_child(instance)
		persons.THIRD:
			var collider = aimraythird.get_collider()
			if aimraythird.is_colliding():
				instance.init(mp7_barrel.global_position, aimraythird.get_collision_point())
				get_parent().add_child(instance)
				if aimraythird.get_collider().is_in_group("enemy"):
					# **
					aimraythird.get_collider().enemy_hit(_weapon_resource.get(0))
					instance.trriger_particles(aimraythird.get_collision_point(), mp7_barrel.global_position, true)
				
				# rigi发射 **
				elif collider.is_in_group("moveObject"):
					# 获取Ray的方向
					var ray_direction = -aimray.global_transform.basis.z.normalized()

					# 反向推力
					var push_direction = ray_direction

					# 冲击力度
					var force = push_direction * 5.0
					collider.apply_central_impulse(force)
				else:
					instance.trriger_particles(aimraythird.get_collision_point(), mp7_barrel.global_position, false)
			else:
				instance.init(mp7_barrel.global_position, aimrayendthird.global_position)
				get_parent().add_child(instance)


# bullet aim ray function
func get_aim_target(person):
	match person:
		persons.FIRST:
			if aimray.is_colliding():
				instance.set_velocity(aimray.get_collision_point())
				#return aimray.get_collision_point()
			else:
				instance.set_velocity(aimrayend.global_position)
				#return aimrayend.global_position
		persons.THIRD:
			if aimraythird.is_colliding():
				instance.set_velocity(aimraythird.get_collision_point())
				#return aimraythird.get_collision_point()
			else:
				instance.set_velocity(aimrayendthird.global_position)
				#return aimrayendthird.global_position


# 子弹弹匣
func weapon_ammo(new_weapon):
	for weaponn in _weapon_resource:
		wealist[weaponn.Weapon_name] = weaponn
	match new_weapon:
		weapons.MP7:
			current_ammo = wealist.get("MP7").Current_Ammo
			reserve_ammo = wealist.get("MP7").Reserve_Ammo
			emit_signal("Update_Ammo", [current_ammo, reserve_ammo])
		weapons.PISTOL:
			current_ammo = wealist.get("PISTOL").Current_Ammo
			reserve_ammo = wealist.get("PISTOL").Reserve_Ammo
			emit_signal("Update_Ammo", [current_ammo, reserve_ammo])


# 弹药补给站 Ammunition Apply Point
func Ammo_apply_point(new_weapon):
	match new_weapon:
		weapons.MP7:
			if wealist.get("MP7").Reserve_Ammo != 0:
				wealist.get("MP7").Current_Ammo = wealist.get("MP7").Current_Ammo + (wealist.get("MP7").magazine - wealist.get("MP7").Current_Ammo)
				wealist.get("MP7").Reserve_Ammo = wealist.get("MP7").Reserve_Ammo + (wealist.get("MP7").Max_Ammo - wealist.get("MP7").Reserve_Ammo)
				emit_signal("Update_Ammo", [wealist.get("MP7").Current_Ammo, wealist.get("MP7").Reserve_Ammo])
			elif wealist.get("MP7").Reserve_Ammo == 0 && wealist.get("MP7").Current_Ammo == 0:
				wealist.get("MP7").Current_Ammo = wealist.get("MP7").Current_Ammo + wealist.get("MP7").magazine
				wealist.get("MP7").Reserve_Ammo = wealist.get("MP7").Reserve_Ammo + wealist.get("MP7").Max_Ammo
				emit_signal("Update_Ammo", [wealist.get("MP7").Current_Ammo, wealist.get("MP7").Reserve_Ammo])
		weapons.PISTOL:
			if wealist.get("PISTOL").Reserve_Ammo != 0:
				wealist.get("PISTOL").Current_Ammo = wealist.get("PISTOL").Current_Ammo + wealist.get("PISTOL").magazine - wealist.get("PISTOL").Current_Ammo
				wealist.get("PISTOL").Reserve_Ammo = wealist.get("PISTOL").Reserve_Ammo + (wealist.get("PISTOL").Max_Ammo - wealist.get("PISTOL").Reserve_Ammo)
				emit_signal("Update_Ammo", [wealist.get("PISTOL").Current_Ammo, wealist.get("PISTOL").Reserve_Ammo])
			elif wealist.get("PISTOL").Reserve_Ammo == 0 && wealist.get("PISTOL").Current_Ammo == 0:
				wealist.get("PISTOL").Current_Ammo = wealist.get("PISTOL").Current_Ammo + wealist.get("PISTOL").magazine
				wealist.get("PISTOL").Reserve_Ammo = wealist.get("PISTOL").Reserve_Ammo + wealist.get("PISTOL").Max_Ammo
				emit_signal("Update_Ammo", [wealist.get("PISTOL").Current_Ammo, wealist.get("PISTOL").Reserve_Ammo])


# reloading
func reload_ammo(reload_weapon):
	if !mp7ani.is_playing() or !gun_ani.is_playing():
		match reload_weapon:
			weapons.MP7:
				mp7ani.play("reload")
				var reload_count = min(wealist.get("MP7").magazine - wealist.get("MP7").Current_Ammo, wealist.get("MP7").Reserve_Ammo)
				wealist.get("MP7").Current_Ammo = wealist.get("MP7").Current_Ammo + reload_count
				wealist.get("MP7").Reserve_Ammo = wealist.get("MP7").Reserve_Ammo - reload_count
				emit_signal("Update_Ammo", [wealist.get("MP7").Current_Ammo, wealist.get("MP7").Reserve_Ammo])
				if reserve_ammo == 0:
					no_more_bullet.set_text("No quedan municiones.")
					await get_tree().create_timer(0.5).timeout
					no_more_bullet.set_text("")
			weapons.PISTOL:
				gun_ani.play("reload")
				var reload_count = min(wealist.get("PISTOL").magazine - wealist.get("PISTOL").Current_Ammo, wealist.get("PISTOL").Reserve_Ammo)
				wealist.get("PISTOL").Current_Ammo = wealist.get("PISTOL").Current_Ammo + reload_count
				wealist.get("PISTOL").Reserve_Ammo = wealist.get("PISTOL").Reserve_Ammo - reload_count
				emit_signal("Update_Ammo", [wealist.get("PISTOL").Current_Ammo, wealist.get("PISTOL").Reserve_Ammo])
				if reserve_ammo == 0:
					no_more_bullet.set_text("No quedan municiones.")
					await get_tree().create_timer(0.8).timeout
					no_more_bullet.set_text("")


# 交换武器
# 放下
func _lowe_weapon():
	match weapon:
		weapons.MP7:
			mp7ani.play_backwards("raise")
		weapons.PISTOL:
			gun_ani.play_backwards('raise')


# 升起
func _raise_weapon(new_weapon):
	can_shoot = false
	_lowe_weapon()
	await get_tree().create_timer(0.3).timeout
	match new_weapon:
		weapons.MP7:
			mp7ani.play("raise")
		weapons.PISTOL:
			gun_ani.play("raise")
	weapon = new_weapon
	can_shoot = true


# 敌人攻击我们
func take_damage(dir):
	# dir是敌人攻击我们方位
	# TODO: 显示敌人攻击的方向
	#emit_signal("player_hit")
	# 击中特效
	damage()
	hit_rect.visible = true
	await get_tree().create_timer(0.2).timeout
	hit_rect.visible = false


# pick object
func pickup_object():
	var collider = pickray.get_collider()
	if collider != null and collider is RigidBody3D and !can_shoot: # **
		pick_object = collider
		joint.set_node_b(pick_object.get_path())
		
		
# remove object
func remove_object():
	if pick_object != null:
		pick_object = null
		joint.set_node_b(joint.get_path())


# Animation tree about movement
func handle_animation():
	match CurrentAni:
		IDLE:
			animation_tree.set("parameters/Movement/transition_request", "Idle")
		WALK:
			animation_tree.set("parameters/Movement/transition_request", "Walk")
		RUN:
			animation_tree.set("parameters/Movement/transition_request", "Run")
		CROUCH:
			animation_tree.set("parameters/Movement/transition_request", "Crouch")
			
			
func jump():
	animation_tree.set("parameters/JumpShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	

## 更新血条状态
func _update_health_stat() -> void:
	# **
	health_bar.value = health
	var int_health: int = ceil(health)
	health_label.text = "%s" %int_health


## 角色死亡
func _on_player_died():
	health = max_health
	_update_health_stat()
	player_died.emit()


## 收到伤害并且更新血条状态
func damage():
	# **
	# TODO: 更改为敌人的伤害
	health -= 10
	if health <= 0:
		_on_player_died()
	_update_health_stat()


## 初始化玩家状态
func setup_player_stats() -> void:
	max_health = playerStats.current_max_health
	# **
	health = playerStats.current_max_health
	health_bar.max_value = max_health
	_update_health_stat()
	playerStats.died.connect(_on_player_died)


func _on_enemy_hit() -> void:
	# 击中反馈
	crosshairhit.visible = true
	await get_tree().create_timer(0.1).timeout
	crosshairhit.visible = false 
