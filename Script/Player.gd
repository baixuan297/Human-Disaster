extends CharacterBody3D

# Import
# first
@onready var nek = $firstperson/nek
@onready var head = $firstperson/nek/head
@onready var eyes = $firstperson/nek/head/eyes
@onready var de_pie = $Stand
@onready var cucilla = $Crouch
@onready var raycast3d = $RayCast3D
@onready var camera = $firstperson/nek/head/eyes/Camera3D
# third
@onready var t_person = $thirdperson
@onready var third_person = $thirdperson/Camera3D
# player
@onready var armature = $fishman/Armature/Skeleton3D
# effect
@onready var hit_rect: ColorRect = $ColorRect
# animation
@onready var animation_player = $fishman/AnimationPlayer
@onready var player = $fishman
@onready var animation_tree = $fishman/AnimationTree
# Weapon attack
# Pistol
@onready var gun_ani = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/PistolSubView/SubViewport/model_camara_pistol/rig/gun/AnimationPlayer
@onready var gun = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/PistolSubView/SubViewport/model_camara_pistol
@onready var gun_barrel = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/PistolSubView/SubViewport/model_camara_pistol/rig/gun/pistol/RayCast3D
# MP7
@onready var mp7ani = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/MP7SubView/SubViewport/model_camara_mp7/rig/gun/AnimationPlayer
@onready var gunmp7 = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/MP7SubView/SubViewport/model_camara_mp7
@onready var mp7_barrel = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/MP7SubView/SubViewport/model_camara_mp7/rig/gun/mp7/meshes/barrel
# aim ray
@onready var aimray = $firstperson/nek/head/eyes/Camera3D/Aimray
@onready var aimraythird = $thirdperson/Camera3D/Aimray
@onready var aimrayend = $firstperson/nek/head/eyes/Camera3D/aimrayend
@onready var aimrayendthird = $thirdperson/Camera3D/aimrayend

# persons change enum
enum persons {FIRST, THIRD}
var current_person = persons.FIRST

#export
@export var sense_hori = 0.15
@export var sense_vert = 0.15

var yaw := 0.0
var pitch := 0.0

# first
# Velocitat
var SPEED_Normal = 5.0
const JUMP_VELOCITY = 7.0
const speed_walk = 5.0
const speed_run = 8.0
const speed_crouch = 2.0
const speed_mouse = 0.1
const hit_stagger = 8.0

# Velocitat que acelera poco a poco
var air_lerp = 3.0
var speed_lerp = 10.0
var direction = Vector3.ZERO

# var free_look_amount = 5
# slide vars
var slide_timer: float = 1
var slide_time_max: float = 1.0
var slide_vector = Vector2.ZERO
var slide_speed: float = 10.0

# movimiento de capeza
const move_sprint = 22.0
const move_walk = 15.0
const move_crouch = 10.0

const move_sprint_intensity = 0.2
const move_walk_intensity = 0.1
const move_crouch_intensyty = 0.05

var head_move_vector = Vector2.ZERO
var head_move_index = 0.0
var head_move_current = 0.0

const altura_head = 1.0

# states
var walking = false
var freelook = false
var crouching = false
var sprinting = false
var sliding = false
var moving = false
var jumping = false

#third
const t_speed_mouse = 0.1

# gun bullet
var bullet = preload("res://blender/gun/bullet.tscn")
var instance
var bullettrail = preload("res://blender/gun/bullettrail.tscn")

# 玩家被攻击信号
signal player_hit

# weapon switching
enum weapons {
	MP7,
	PISTOL,
	HAND
}
# 当前武器
var weapon = weapons.HAND
# 是否允许射击
var can_shoot = true

# pick object
@onready var pickray = $firstperson/nek/head/eyes/Camera3D/pickray
@onready var holdposition = $firstperson/nek/head/eyes/Camera3D/HoldPosition
@onready var joint = $firstperson/nek/head/eyes/Camera3D/Generic6DOFJoint3D
@onready var staticbody = $firstperson/nek/head/eyes/Camera3D/StaticBody3D

var pick_object : Object
var rotation_power = 0.05

# animation
enum {IDLE, WALK, RUN, CROUCH, JUMP}
var CurrentAni = IDLE

# ammo, reload ammo
@onready var Ammo_container = $"../UI/HBoxContainer"
@onready var no_more_bullet = $"../UI/No_more_bullet"

signal Update_Ammo

@export var _weapon_resource : Array[Weapon_Resource]

var current_ammo = ""
var reserve_ammo = ""
var wealist = {}

# ammo apply point
@onready var interactable_ray = $firstperson/nek/head/eyes/Camera3D/Interactable

# mp7_model_view
@onready var mp7_model_view_camera = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/MP7SubView/SubViewport/model_camara_mp7
@onready var pistol_model_view_camera = $firstperson/nek/head/eyes/Camera3D/Weapon_manager/PistolSubView/SubViewport/model_camara_pistol

# spaceship
@onready var spacheani = $"../stage/NavigationRegion3D/spaceship_interior1/AnimationPlayer"

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# set vieport position and size
	$firstperson/nek/head/eyes/Camera3D/Weapon_manager/MP7SubView/SubViewport.size = DisplayServer.window_get_size()
	$firstperson/nek/head/eyes/Camera3D/Weapon_manager/PistolSubView/SubViewport.size = DisplayServer.window_get_size()
	# 多人游戏同步
	# $MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())

func _input(event):	
	if event is InputEventMouseMotion:
		#moving = Input.is_action_pressed("move_right") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_back") or Input.is_action_pressed("move_forward")
		# first
		if freelook and camera.is_current():
			nek.rotate_y(deg_to_rad(-event.relative.x * speed_mouse))
			nek.rotation.y = clamp(nek.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		else:
			if camera.is_current():
				rotate_y(deg_to_rad(-event.relative.x * speed_mouse))
		if camera.is_current():
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
		if camera.is_current():
			camera.clear_current(true)
		else:
			third_person.clear_current(true)

	# shoot
	if Input.is_action_just_pressed("shoot"):
		if can_shoot:
			match weapon:
				weapons.PISTOL:
					_shoot_pistols()
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
		
		# space ship open the door
		# 打算使用position的方式来实现批量开关门，不行就一个一个来。
		if collider.is_in_group('door1'):
			spacheani.play("Opendoor1")
			await get_tree().create_timer(8.0).timeout
			spacheani.play_backwards("Opendoor1")
		elif collider.is_in_group('door2'):
			spacheani.play("Opendoor2")
			await get_tree().create_timer(8.0).timeout
			spacheani.play_backwards("Opendoor2")
		elif collider.is_in_group('door3'):
			spacheani.play("Opendoor3")
			await get_tree().create_timer(8.0).timeout
			spacheani.play_backwards("Opendoor3")
		
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
	
func _physics_process(delta):
	#if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
	handle_animation()
	# Para tener el input de movimiento
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# mp7_model_view transform
	mp7_model_view_camera.global_transform = camera.global_transform
	pistol_model_view_camera.global_transform = camera.global_transform
	
	# Pulsa alguno teclado
	# crouch
	if Input.is_action_pressed("crouch") || sliding:
		SPEED_Normal = lerp(SPEED_Normal, speed_crouch, delta * speed_lerp)
		head.position.y = lerp(head.position.y, -1.6 + altura_head, delta * speed_lerp)
		de_pie.disabled = true
		cucilla.disabled = false
		
		# slide start logic
		if sprinting && input_dir != Vector2.ZERO:
			sliding = true
			slide_timer = slide_time_max 
			slide_vector = input_dir
			freelook = true
		
		walking = false
		crouching = true
		sprinting = false
		jumping = false
	elif !raycast3d.is_colliding():
		de_pie.disabled = false
		cucilla.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta * speed_lerp)
		if Input.is_action_pressed("Run") and Input.is_action_pressed("move_forward"):
			SPEED_Normal = lerp(SPEED_Normal, speed_run, delta * speed_lerp)
			walking = true
			crouching = false
			sprinting = true
			jumping = false
		elif not input_dir:
			walking = false
			sprinting = false
			crouching = false
		else:
			SPEED_Normal = lerp(SPEED_Normal, speed_walk, delta * speed_lerp)
			walking = true
			crouching = false
			sprinting = false
			jumping = false
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
			sliding = false
			jumping = true
			jump()

	# free look
	if Input.is_action_pressed("free_look") || sliding:
		freelook = true
	else:
		freelook = false
		nek.rotation.y = lerp(nek.rotation.y, 0.0, delta * speed_lerp)
		
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			slide_timer = false
			freelook = false

	# head bobbing
	if sprinting:
		head_move_current = move_sprint_intensity
		head_move_index += move_sprint*delta
	elif walking and !sprinting:
		head_move_current = move_walk_intensity
		head_move_index += move_walk*delta
	else:
		head_move_current = move_crouch_intensyty
		head_move_index += move_crouch*delta

	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		# 摇头晃脑
		head_move_vector.y = sin(head_move_index)
		head_move_vector.x = sin(head_move_index/2) + 0.5

		eyes.position.y = lerp(eyes.position.y, head_move_vector.y * (head_move_current/2.0), delta * speed_lerp)
		eyes.position.x = lerp(eyes.position.x, head_move_vector.x * head_move_current, delta * speed_lerp)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * speed_lerp)
		eyes.position.x = lerp(eyes.position.y, 0.0, delta * speed_lerp)

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_on_floor():
		direction = lerp(direction, (transform.basis * Vector3(-input_dir.x, 0.0, -input_dir.y)).normalized(), delta * speed_lerp)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction, (transform.basis * Vector3(-input_dir.x, 0.0, -input_dir.y)).normalized(), delta * air_lerp)

	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x,0.0,slide_vector.y)).normalized()
		SPEED_Normal = slide_timer * slide_speed

	if direction:
		if is_on_floor() and sprinting and walking:
			CurrentAni = RUN
			if third_person.is_current():
				player.look_at(-direction + position, Vector3.UP)
		elif walking:
			CurrentAni = WALK
			if third_person.is_current():
				player.look_at(-direction + position, Vector3.UP)
		elif crouching:
			CurrentAni = CROUCH
		else:
			CurrentAni = IDLE


		velocity.x = direction.x * SPEED_Normal
		velocity.z = direction.z * SPEED_Normal

	else:
		if is_on_floor() and !crouching:
			CurrentAni = IDLE

		velocity.x = move_toward(velocity.x, 0, SPEED_Normal)
		velocity.z = move_toward(velocity.z, 0, SPEED_Normal)

	# pick object
	if pick_object != null:
		var a = pick_object.global_transform.origin
		var b = holdposition.global_transform.origin
		pick_object.set_linear_velocity((b-a) * 10)

	# weapon switch
	if Input.is_action_just_pressed("change_weapon1") and weapon != weapons.MP7:
		_raise_weapon(weapons.MP7)
		weapon_ammo(weapons.MP7)
		await get_tree().create_timer(0.4).timeout
		gun.visible = false
		gunmp7.visible = true
		Ammo_container.visible = true
	if Input.is_action_just_pressed("change_weapon2") and weapon != weapons.PISTOL:
		_raise_weapon(weapons.PISTOL)
		weapon_ammo(weapons.PISTOL)
		gunmp7.visible = false
		gun.visible = true
		Ammo_container.visible = true
	if Input.is_action_just_pressed("change_hand"):
		weapon = weapons.HAND
		Ammo_container.visible = false
		gun.visible = false
		gunmp7.visible = false
		can_shoot = false
			
	# 让mp7可以单按一直射 **
	if Input.is_action_pressed("shoot"):
		if can_shoot:
			match weapon:
				weapons.MP7:
					_auto_shot()
					weapon_ammo(weapons.MP7)
	
	_change_person()
	_body_switch()
	move_and_slide()
		
func _change_person():
	if camera.is_current():
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
			instance = bullet.instantiate()
			instance.position = gun_barrel.global_position
			get_parent().add_child(instance)
			if camera.is_current():
				pistol_aimray(persons.FIRST)
			if third_person.is_current():
				pistol_aimray(persons.THIRD)
			wealist.get("PISTOL").Current_Ammo -= 1
	else:
		reload_ammo(weapons.PISTOL)
		
func _auto_shot():
	if !mp7ani.is_playing():
		if wealist.get("MP7").Current_Ammo != 0:
				mp7ani.play("fire")
				instance = bullettrail.instantiate()
				if camera.is_current():
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
				if aimray.get_collider().is_in_group('enemy'):
					aimray.get_collider().hit()
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
				if aimraythird.get_collider().is_in_group('enemy'):
					aimraythird.get_collider().hit()
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
func pistol_aimray(person):
	match person:
		persons.FIRST:
			if aimray.is_colliding():
				instance.set_velocity(aimray.get_collision_point())
			else:
				instance.set_velocity(aimrayend.global_position)
		persons.THIRD:
			if aimraythird.is_colliding():
				instance.set_velocity(aimraythird.get_collision_point())
			else:
				instance.set_velocity(aimrayendthird.global_position)

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
func hit(dir):
	emit_signal("player_hit")
	# 击中特效
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
