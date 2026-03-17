extends Node3D
## MovementAudioComponent
## 负责：
##  1）保存脚步音资源并播放（走/跑/跳/落地/蹲）
##  2）根据 MovementComponent 移动状态自动触发脚步与落地音

@export var audio_data: FootStepAudioData

@onready var walk : AudioStreamPlayer3D = $Walk
@onready var jump_player: AudioStreamPlayer3D = $Jump
@onready var land_player: AudioStreamPlayer3D = $Land
@onready var crouch_player: AudioStreamPlayer3D = $Crouch

var walk_index := 0
var run_index := 0
var crouch_walk_index := 0

var movement_component: Node = null
var _footstep_timer: float = 0.0
var _crouch_step_timer: float = 0.0


func _ready() -> void:
	if audio_data == null:
		push_warning("MovementAudioComponent: audio_data 未设置，将不播放脚步音效。")


func setup(p_movement_component: Node) -> void:
	movement_component = p_movement_component
	if movement_component:
		if movement_component.has_signal("landed") and not movement_component.landed.is_connected(_on_landed):
			movement_component.landed.connect(_on_landed)
		if movement_component.has_signal("jumped") and not movement_component.jumped.is_connected(_on_jumped):
			movement_component.jumped.connect(_on_jumped)
		# crouch 音改为蹲走时按节奏播放，不再连接 crouched 信号


## ========= MovementComponent 驱动部分 =========

func _on_landed() -> void:
	play_land()

func _on_jumped() -> void:
	play_jump()


func _physics_process(delta: float) -> void:
	if movement_component == null or audio_data == null:
		return
	var state = movement_component.current_state
	var character = movement_component.character if "character" in movement_component else null
	if character == null or not character.is_on_floor():
		_footstep_timer = 0.0
		return

	# 走路/跑步：按节奏播放脚步
	if state in [movement_component.PlayerState.WALKING, movement_component.PlayerState.SPRINTING]:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			var is_running = state == movement_component.PlayerState.SPRINTING
			if is_running:
				play_run_step()
				_footstep_timer = 0.3
			else:
				play_walk_step()
				_footstep_timer = 0.45
		_crouch_step_timer = 0.0
	else:
		_footstep_timer = 0.0

	# 蹲下且在地面且正在移动：按节奏播放蹲下脚步（单独计时器）
	var dir_len_sq: float = movement_component.direction.length_squared() if "direction" in movement_component else 0.0
	if state == movement_component.PlayerState.CROUCHING and dir_len_sq > 0.01:
		_crouch_step_timer -= delta
		if _crouch_step_timer <= 0.0:
			play_crouch()
			_crouch_step_timer = 0.55
	else:
		_crouch_step_timer = 0.0


## ========= 具体动作音效接口 =========

func play_walk_step() -> void:
	if audio_data == null or audio_data.walk_steps.is_empty():
		return
	var stream: AudioStream = audio_data.walk_steps[walk_index]
	walk_index = (walk_index + 1) % audio_data.walk_steps.size()
	_play_with_random(walk, stream)


func play_run_step() -> void:
	if audio_data == null or audio_data.run_steps.is_empty():
		return
	var stream: AudioStream = audio_data.run_steps[run_index]
	run_index = (run_index + 1) % audio_data.run_steps.size()
	_play_with_random(walk, stream)


func play_crouch() -> void:
	if audio_data == null or audio_data.crouch_sound.is_empty():
		return
	var stream: AudioStream = audio_data.crouch_sound[crouch_walk_index]
	crouch_walk_index = (crouch_walk_index + 1) % audio_data.crouch_sound.size()
	_play_with_random(crouch_player, stream)


func play_jump() -> void:
	if audio_data == null or audio_data.jump_sound == null:
		return
	_play_simple(jump_player, audio_data.jump_sound)


func play_land() -> void:
	if audio_data == null or audio_data.land_sound == null:
		return
	_play_simple(land_player, audio_data.land_sound)
	

## ========= 内部辅助播放函数 =========

func _play_with_random(player: AudioStreamPlayer3D, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.pitch_scale = randf_range(audio_data.pitch_min, audio_data.pitch_max)
	player.volume_db = randf_range(audio_data.volume_min_db, audio_data.volume_max_db)
	player.play()


func _play_simple(player: AudioStreamPlayer3D, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.pitch_scale = 1.0
	player.volume_db = 0.0
	player.play()
