extends BaseEnemy

## enemy.gd — 通用近战敌人（完整状态机）
##
## 架构：AnimationTree 负责动画切换，代码负责游戏逻辑
##   - 代码：状态机（IDLE/CHASE/ATTACK 等）、何时触发 _anim_set("attack", true)
##   - AnimationTree：run/attack/die 条件 → 实际播放动画，Method Track 调用 _hit_finished
##   - 伤害统一走 Stats.take_damage(AttackData)，触发 health_changed → UI 更新
##
## 状态流：
##   IDLE ──(发现玩家)──► CHASE ──(进入攻击范围)──► ATTACK
##     ▲                     ▲                          │
##     └──(失去玩家)──────────┘◄────(离开攻击范围)────────┘
##
##   任意状态 ──(受击+概率)──► STUNNED ──(计时结束)──► CHASE / IDLE
##   任意状态 ──(血量≤0)────► DEAD（动画 → queue_free）
##
## AnimationTree 条件：parameters/conditions/run | attack | die | stun


# ── 状态枚举 ──────────────────────────────────────────────────────────────────

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	STUNNED,
	DEAD,
}


# ── 可配置参数 ────────────────────────────────────────────────────────────────

@export_group("移动")
@export var move_speed:        float = 5.0
@export var patrol_radius:     float = 8.0   ## 巡逻半径（以出生点为圆心）
@export var patrol_wait_time:  float = 2.5   ## 到达巡逻点后等待时间（秒）

@export_group("感知")
@export var detection_range:   float = 15.0  ## 发现玩家的半径
@export var lose_target_range: float = 22.0  ## 超过此距离丢失目标

@export_group("战斗")
@export var attack_range:      float = 2.0   ## 攻击触发距离
@export var attack_cooldown:   float = 1.2   ## 两次攻击最短间隔（秒）
@export var stun_on_hit_chance:float = 0.25  ## 受击触发硬直概率
@export var stun_duration:     float = 0.8   ## 硬直持续时间（秒）
@export var base_damage:       float = 10.0  ## 无 Stats 时的备用攻击伤害


# ── 节点引用 ──────────────────────────────────────────────────────────────────

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree     = $AnimationTree


# ── 运行时变量 ────────────────────────────────────────────────────────────────

var _state:          State              = State.IDLE
var _player:         CharacterBody3D
var _anim_playback                       ## AnimationTree StateMachine playback

var _state_timer:    float = 0.0
var _attack_timer:   float = 0.0
var _idle_timer:     float = 0.0

## 巡逻
var _spawn_pos:      Vector3 = Vector3.ZERO
var _patrol_target:  Vector3 = Vector3.ZERO
var _patrol_waiting: bool    = false

## 防止 died 多次触发
var _is_dead:        bool    = false


# =============================================================================
# 生命周期
# =============================================================================

func _ready() -> void:
	super._ready()   ## BaseEnemy 连接 stats.health_changed + stats.died

	_player     = get_tree().get_first_node_in_group("Player")
	_spawn_pos  = global_position
	_anim_playback = anim_tree.get("parameters/playback")

	_enter_state(State.IDLE)


func _process(delta: float) -> void:
	## Stats 是 Resource，不能自驱 Timer，由此处每帧 push
	if stats:
		stats.process_effects(delta)

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_update_state(delta)


# =============================================================================
# 状态机
# =============================================================================

func _update_state(delta: float) -> void:
	match _state:
		State.IDLE:    _update_idle(delta)
		State.PATROL:  _update_patrol(delta)
		State.CHASE:   _update_chase(delta)
		State.ATTACK:  _update_attack(delta)
		State.STUNNED: _update_stunned(delta)
		State.DEAD:    pass


func _enter_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state       = new_state
	_state_timer = 0.0

	match new_state:
		State.IDLE:
			velocity = Vector3.ZERO
			_anim_set("run",    false)
			_anim_set("attack", false)
			#_anim_set("stun",   false)

		State.PATROL:
			_patrol_waiting = false
			_patrol_target  = _pick_patrol_point()
			nav_agent.set_target_position(_patrol_target)
			_anim_set("run",    true)
			_anim_set("attack", false)

		State.CHASE:
			_anim_set("run",    true)
			_anim_set("attack", false)
			#_anim_set("stun",   false)

		State.ATTACK:
			velocity = Vector3.ZERO
			_anim_set("run",    false)
			_anim_set("attack", true)

		State.STUNNED:
			velocity = Vector3.ZERO
			_anim_set("run",    false)
			_anim_set("attack", false)
			#_anim_set("stun",   true)

		State.DEAD:
			velocity = Vector3.ZERO
			_anim_set("die", true)


# ── 各状态 Update ─────────────────────────────────────────────────────────────

func _update_idle(delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()

	_idle_timer += delta
	if _idle_timer < 1.5:
		return
	_idle_timer = 0.0

	if _can_see_player():
		_enter_state(State.CHASE)
	elif randf() < 0.40:
		_enter_state(State.PATROL)


func _update_patrol(delta: float) -> void:
	## 随时发现玩家立即切换
	if _can_see_player():
		_enter_state(State.CHASE)
		return

	if _patrol_waiting:
		_state_timer += delta
		if _state_timer >= patrol_wait_time:
			_patrol_waiting = false
			_patrol_target  = _pick_patrol_point()
			nav_agent.set_target_position(_patrol_target)
			_state_timer    = 0.0
		velocity = Vector3.ZERO
		move_and_slide()
		return

	nav_agent.set_target_position(_patrol_target)

	if nav_agent.is_navigation_finished():
		_patrol_waiting = true
		_state_timer    = 0.0
		return

	_move_toward(nav_agent.get_next_path_position(), move_speed * 0.55, delta)


func _update_chase(delta: float) -> void:
	if not is_instance_valid(_player):
		_enter_state(State.IDLE)
		return

	var dist: float = global_position.distance_to(_player.global_position)

	if dist > lose_target_range:
		_enter_state(State.IDLE)
		return

	if dist <= attack_range and _attack_timer <= 0.0:
		_enter_state(State.ATTACK)
		return

	nav_agent.set_target_position(_player.global_position)
	_move_toward(nav_agent.get_next_path_position(), move_speed, delta)


func _update_attack(delta: float) -> void:
	if not is_instance_valid(_player):
		_enter_state(State.IDLE)
		return

	## 始终面朝玩家（Y 轴旋转）
	var look_target := Vector3(
		_player.global_position.x, global_position.y, _player.global_position.z
	)
	if look_target != global_position:
		look_at(look_target, Vector3.UP)

	## 玩家跑远 → 追击
	if global_position.distance_to(_player.global_position) > attack_range + 0.8:
		_enter_state(State.CHASE)
		return

	## 超时切回（防止动画无 Method Track 时卡住）
	_state_timer += delta
	if _state_timer >= 1.5:
		_attack_timer = attack_cooldown
		_anim_set("attack", false)
		_anim_set("run", true)
		_enter_state(State.CHASE)


func _update_stunned(delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()

	_state_timer += delta
	if _state_timer < stun_duration:
		return

	if _can_see_player():
		_enter_state(State.CHASE)
	else:
		_enter_state(State.IDLE)


# =============================================================================
# 公共接口
# =============================================================================

## 外部施加眩晕（技能命中、环境陷阱等）
func apply_stun(duration: float) -> void:
	if _state == State.DEAD:
		return
	stun_duration = duration
	_enter_state(State.STUNNED)


## 受到伤害时额外判断是否触发硬直（由 BaseEnemy._on_area_3d_body_part_hit 之后调用或信号绑定）
## 调用方式：将此方法连接到 stats.health_changed，或在 BaseEnemy 子类中覆盖 _on_health_changed
func on_received_damage() -> void:
	if _state in [State.DEAD, State.STUNNED]:
		return
	if randf() < stun_on_hit_chance:
		_enter_state(State.STUNNED)


# =============================================================================
# 动画回调
# =============================================================================

## AnimationTree Method Track 调用 — 攻击动画命中帧
## （在编辑器 AnimationTree 的攻击动画里，用 Method Track 绑定此函数）
func _hit_finished() -> void:
	_attack_timer = attack_cooldown

	if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= attack_range + 1.0:
		if _player.has_method("apply_attack_data"):
			var dmg := base_damage
			if stats:
				dmg = stats.current_attack
			var attack := AttackData.new()
			attack.source = AttackData.AttackType.WEAPON
			attack.source_node = self
			attack.base_damage = dmg
			attack.final_damage = dmg
			attack.body_part_multiplier = 1.0
			_player.apply_attack_data(attack)
		elif _player.has_method("take_damage"):
			_player.take_damage()

	## 攻击动画结束后切回追击（否则状态机卡在 attack）
	get_tree().create_timer(0.5).timeout.connect(_on_attack_anim_done, CONNECT_ONE_SHOT)


func _on_attack_anim_done() -> void:
	if _state != State.ATTACK or _is_dead:
		return
	_anim_set("attack", false)
	_anim_set("run", true)
	if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= lose_target_range:
		_enter_state(State.CHASE)
	else:
		_enter_state(State.IDLE)


# =============================================================================
# BaseEnemy 虚函数重写
# =============================================================================

## 覆盖 BaseEnemy._on_health_changed — 受击时触发硬直判定
func _on_health_changed(current_health: float, maximum_health: float) -> void:
	super._on_health_changed(current_health, maximum_health)
	on_received_damage()


## 覆盖 BaseEnemy._on_died（通过 stats.died 信号触发）
func _on_died() -> void:
	if _is_dead:
		return
	_is_dead = true

	print("💀 [%s] 死亡" % name)
	_enter_state(State.DEAD)
	delete_collision_nodes(self)

	## BaseEnemy 定义了 stats_node，加 null 检查防止场景结构不一致时崩溃
	if stats_node and is_instance_valid(stats_node):
		stats_node.queue_free()

	## 等待死亡动画（2 秒备用）
	await get_tree().create_timer(2.0).timeout
	queue_free()


# =============================================================================
# 辅助方法
# =============================================================================

func _can_see_player() -> bool:
	if not is_instance_valid(_player):
		return false
	return global_position.distance_to(_player.global_position) <= detection_range


func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var dir := (target - global_position)
	dir.y = 0.0

	if dir.length_squared() < 0.01:
		velocity = Vector3.ZERO
	else:
		dir      = dir.normalized()
		velocity = dir * speed
		rotation.y = lerp_angle(
			rotation.y,
			atan2(-velocity.x, -velocity.z),
			delta * 12.0
		)
	move_and_slide()


func _pick_patrol_point() -> Vector3:
	var angle  := randf_range(0.0, TAU)
	var radius := randf_range(patrol_radius * 0.3, patrol_radius)
	return _spawn_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


## 设置 AnimationTree 条件参数（attack/run/die 等，需在 BlendTree 中配置同名条件）
func _anim_set(cond: String, value: bool) -> void:
	if anim_tree:
		anim_tree.set("parameters/conditions/" + cond, value)
