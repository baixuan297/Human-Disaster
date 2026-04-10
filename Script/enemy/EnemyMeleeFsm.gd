extends RefCounted
class_name EnemyMeleeFsm

## 近战巡逻/追击/攻击/硬直状态机。宿主须为 CharacterBody3D（通常为 BaseEnemy 子类），并带有 enemy.gd 同款的导出战斗参数。

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	STUNNED,
	DEAD,
}

const _ATTACK_STATE_TIMEOUT := 1.5
const _ATTACK_ANIM_TAIL_SEC := 0.5
const _IDLE_PULSE_SEC := 1.5
const _PATROL_SPEED_MULT := 0.55

var state: State = State.IDLE

var _body: CharacterBody3D
var _nav: NavigationAgent3D
var _anim: EnemyAnimationConditions

var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _idle_timer: float = 0.0

var _spawn_pos: Vector3 = Vector3.ZERO
var _patrol_target: Vector3 = Vector3.ZERO
var _patrol_waiting: bool = false

var _combat_target: Node3D
var _host_dead: bool = false


func setup(host: CharacterBody3D, nav: NavigationAgent3D, anim_tree: AnimationTree) -> void:
	_body = host
	_nav = nav
	_anim = EnemyAnimationConditions.new(anim_tree)
	_spawn_pos = host.global_position
	enter_state(State.IDLE)


func mark_host_dead() -> void:
	_host_dead = true
	enter_state(State.DEAD)


func process_tick(delta: float) -> void:
	if _host_dead:
		return
	_refresh_combat_target()
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	match state:
		State.IDLE:
			_update_idle(delta)
		State.PATROL:
			_update_patrol(delta)
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			_update_attack(delta)
		State.STUNNED:
			_update_stunned(delta)
		State.DEAD:
			pass


func enter_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_state_timer = 0.0

	match new_state:
		State.IDLE:
			_body.velocity = Vector3.ZERO
			_anim.set_condition("run", false)
			_anim.set_condition("attack", false)
		State.PATROL:
			_patrol_waiting = false
			_patrol_target = EnemyMeleeLocomotion.pick_patrol_point(_spawn_pos, _fp(&"patrol_radius", 8.0))
			_nav.set_target_position(_patrol_target)
			_anim.set_condition("run", true)
			_anim.set_condition("attack", false)
		State.CHASE:
			_anim.set_condition("run", true)
			_anim.set_condition("attack", false)
		State.ATTACK:
			_body.velocity = Vector3.ZERO
			_anim.set_condition("run", false)
			_anim.set_condition("attack", true)
		State.STUNNED:
			_body.velocity = Vector3.ZERO
			_anim.set_condition("run", false)
			_anim.set_condition("attack", false)
		State.DEAD:
			_body.velocity = Vector3.ZERO
			_anim.set_condition("die", true)


func apply_stun(duration: float) -> void:
	if state == State.DEAD:
		return
	_body.set(&"stun_duration", duration)
	enter_state(State.STUNNED)


func on_received_damage() -> void:
	if state == State.DEAD or state == State.STUNNED:
		return
	if randf() < _fp(&"stun_on_hit_chance", 0.25):
		enter_state(State.STUNNED)


func on_hit_finished() -> void:
	_refresh_combat_target()
	_attack_timer = _fp(&"attack_cooldown", 1.2)
	var ar: float = _fp(&"attack_range", 2.0)
	if is_instance_valid(_combat_target) and _body.global_position.distance_to(_combat_target.global_position) <= ar + 1.0:
		if _combat_target.has_method("apply_attack_data"):
			var dmg: float = _fp(&"base_damage", 10.0)
			var be := _body as BaseEnemy
			if be and be.stats:
				dmg = be.stats.current_attack
			var attack := AttackData.new()
			attack.source = AttackData.AttackType.WEAPON
			attack.source_node = _body
			attack.base_damage = dmg
			attack.final_damage = dmg
			attack.body_part_multiplier = 1.0
			_combat_target.apply_attack_data(attack)
		elif _combat_target.has_method("take_damage"):
			_combat_target.take_damage()
	_body.get_tree().create_timer(_ATTACK_ANIM_TAIL_SEC).timeout.connect(_on_attack_anim_done, CONNECT_ONE_SHOT)


func _on_attack_anim_done() -> void:
	if state != State.ATTACK or _host_dead:
		return
	_refresh_combat_target()
	_anim.set_condition("attack", false)
	_anim.set_condition("run", true)
	var lr: float = _fp(&"lose_target_range", 22.0)
	if is_instance_valid(_combat_target) and _body.global_position.distance_to(_combat_target.global_position) <= lr:
		enter_state(State.CHASE)
	else:
		enter_state(State.IDLE)


func _fp(prop: StringName, default: float) -> float:
	var v: Variant = _body.get(prop)
	if v == null:
		return default
	return float(v)


func _refresh_combat_target() -> void:
	var be := _body as BaseEnemy
	if be:
		_combat_target = EnemyCombatTargeting.resolve_combat_target(be)


func _can_see_combat_target() -> bool:
	_refresh_combat_target()
	return EnemyCombatTargeting.can_see_target(_body, _combat_target, _fp(&"detection_range", 15.0))


func _update_idle(delta: float) -> void:
	_body.velocity = Vector3.ZERO
	_body.move_and_slide()
	_idle_timer += delta
	if _idle_timer < _IDLE_PULSE_SEC:
		return
	_idle_timer = 0.0
	if _can_see_combat_target():
		enter_state(State.CHASE)
	elif randf() < 0.40:
		enter_state(State.PATROL)


func _update_patrol(delta: float) -> void:
	if _can_see_combat_target():
		enter_state(State.CHASE)
		return
	if _patrol_waiting:
		_state_timer += delta
		if _state_timer >= _fp(&"patrol_wait_time", 2.5):
			_patrol_waiting = false
			_patrol_target = EnemyMeleeLocomotion.pick_patrol_point(_spawn_pos, _fp(&"patrol_radius", 8.0))
			_nav.set_target_position(_patrol_target)
			_state_timer = 0.0
		_body.velocity = Vector3.ZERO
		_body.move_and_slide()
		return
	_nav.set_target_position(_patrol_target)
	if _nav.is_navigation_finished():
		_patrol_waiting = true
		_state_timer = 0.0
		return
	EnemyMeleeLocomotion.move_toward_on_plane(
		_body,
		_nav.get_next_path_position(),
		_fp(&"move_speed", 5.0) * _PATROL_SPEED_MULT,
		delta
	)


func _update_chase(delta: float) -> void:
	if not is_instance_valid(_combat_target):
		enter_state(State.IDLE)
		return
	var dist: float = _body.global_position.distance_to(_combat_target.global_position)
	if dist > _fp(&"lose_target_range", 22.0):
		enter_state(State.IDLE)
		return
	if dist <= _fp(&"attack_range", 2.0) and _attack_timer <= 0.0:
		enter_state(State.ATTACK)
		return
	_nav.set_target_position(_combat_target.global_position)
	EnemyMeleeLocomotion.move_toward_on_plane(
		_body,
		_nav.get_next_path_position(),
		_fp(&"move_speed", 5.0),
		delta
	)


func _update_attack(delta: float) -> void:
	if not is_instance_valid(_combat_target):
		enter_state(State.IDLE)
		return
	var look_target := Vector3(
		_combat_target.global_position.x, _body.global_position.y, _combat_target.global_position.z
	)
	if look_target != _body.global_position:
		_body.look_at(look_target, Vector3.UP)
	var ar: float = _fp(&"attack_range", 2.0)
	if _body.global_position.distance_to(_combat_target.global_position) > ar + 0.8:
		_enter_chase_after_attack_timeout()
		return
	_state_timer += delta
	if _state_timer >= _ATTACK_STATE_TIMEOUT:
		_enter_chase_after_attack_timeout()


func _enter_chase_after_attack_timeout() -> void:
	_attack_timer = _fp(&"attack_cooldown", 1.2)
	_anim.set_condition("attack", false)
	_anim.set_condition("run", true)
	enter_state(State.CHASE)


func _update_stunned(delta: float) -> void:
	_body.velocity = Vector3.ZERO
	_body.move_and_slide()
	_state_timer += delta
	if _state_timer < _fp(&"stun_duration", 0.8):
		return
	if _can_see_combat_target():
		enter_state(State.CHASE)
	else:
		enter_state(State.IDLE)
