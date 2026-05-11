extends RefCounted
class_name EnemyMeleeFsm

## 近战巡逻/追击/攻击/硬直状态机。宿主须为 CharacterBody3D（通常为 BaseEnemy 子类），并带有 enemy.gd 同款的导出战斗参数。

enum State {
	IDLE,
	PATROL,
	LOOK,
	ALERT,
	CHASE,
	ATTACK,
	RETURN,
	STUNNED,
	DEAD,
}

const _ATTACK_STATE_TIMEOUT := 1.5
const _ATTACK_ANIM_TAIL_SEC := 0.5
const _IDLE_PULSE_SEC := 1.5
const _PATROL_SPEED_MULT := 0.55
const _LOOK_STATE_TIMEOUT := 1.25
const _ALERT_STATE_TIMEOUT := 0.55
## 出手帧判定：在 attack_range 基础上额外放宽（平面距离）
const _ON_HIT_RANGE_BONUS := 1.2
## 攻击状态中若与目标平面距离超过 attack_range + 该值则提前中断（略大于进入阈值，避免来回抖）
const _ATTACK_CANCEL_PLANE_EXTRA := 1.05

var state: State = State.IDLE

var _body: CharacterBody3D
var _nav: NavigationAgent3D
var _anim: EnemyAnimationConditions
var _anim_tree: AnimationTree = null

var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _idle_timer: float = 0.0
var _look_pulse_timer: float = 0.0

var _spawn_pos: Vector3 = Vector3.ZERO
var _anchor_pos: Vector3 = Vector3.ZERO
var _patrol_target: Vector3 = Vector3.ZERO
var _patrol_waiting: bool = false

var _combat_target: Node3D
var _host_dead: bool = false


func setup(host: CharacterBody3D, nav: NavigationAgent3D, anim_tree: AnimationTree) -> void:
	_body = host
	_nav = nav
	_anim = EnemyAnimationConditions.new(anim_tree)
	_anim_tree = anim_tree
	_spawn_pos = host.global_position
	_anchor_pos = _spawn_pos
	enter_state(State.IDLE)


func mark_host_dead() -> void:
	_host_dead = true
	enter_state(State.DEAD)


func process_tick(delta: float) -> void:
	if _host_dead:
		return
	if _is_in_intro_getup():
		_body.velocity = Vector3.ZERO
		_body.move_and_slide()
		_set_anim_flags(false, false, false, true, false, false)
		return
	_refresh_combat_target()
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_process_condition_pulses(delta)
	match state:
		State.IDLE:
			_update_idle(delta)
		State.PATROL:
			_update_patrol(delta)
		State.LOOK:
			_update_look(delta)
		State.ALERT:
			_update_alert(delta)
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			_update_attack(delta)
		State.RETURN:
			_update_return(delta)
		State.STUNNED:
			_update_stunned(delta)
		State.DEAD:
			pass


func enter_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_state_timer = 0.0
	_look_pulse_timer = 0.0

	match new_state:
		State.IDLE:
			_set_ai_damage_invulnerable(false)
			_anchor_pos = _body.global_position
			_body.velocity = Vector3.ZERO
			_set_anim_flags(false, false, false, true, false, false)
		State.PATROL:
			_set_ai_damage_invulnerable(false)
			_patrol_waiting = false
			_patrol_target = EnemyMeleeLocomotion.pick_patrol_point(_spawn_pos, _fp(&"patrol_radius", 8.0))
			_nav.set_target_position(_patrol_target)
			_set_anim_flags(true, false, false, false, false, false)
		State.LOOK:
			# Look：只观察不移动，但允许正常受伤/死亡
			_set_ai_damage_invulnerable(false)
			_body.velocity = Vector3.ZERO
			_set_anim_flags(false, false, false, false, true, false)
		State.ALERT:
			# Screaming（Alert）：动画期间完全免伤，直到切到 run 再追击
			_set_ai_damage_invulnerable(true)
			_body.velocity = Vector3.ZERO
			_set_anim_flags(false, false, true, false, false, false)
		State.CHASE:
			_set_ai_damage_invulnerable(false)
			_set_anim_flags(true, false, true, false, false, false)
		State.ATTACK:
			_set_ai_damage_invulnerable(false)
			_body.velocity = Vector3.ZERO
			_set_anim_flags(false, true, false, false, false, false)
		State.RETURN:
			_set_ai_damage_invulnerable(false)
			_set_anim_flags(false, false, false , true, false, false)
		State.STUNNED:
			_set_ai_damage_invulnerable(false)
			_body.velocity = Vector3.ZERO
			_set_anim_flags(false, false, false, true, false, false)
		State.DEAD:
			_set_ai_damage_invulnerable(false)
			_body.velocity = Vector3.ZERO
			_set_anim_flags(false, false, false, false, false, true)


func on_invulnerable_hit() -> void:
	if state == State.LOOK:
		enter_state(State.ALERT)


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
	if is_instance_valid(_combat_target) and _melee_plane_dist_to_target() <= ar + _ON_HIT_RANGE_BONUS:
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
	_set_anim_flags(true, false, true, false, false, false)
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


## 与目标的平面距离（XZ）。大号胶囊 + 不同枢轴高度时，3D 距离常大于真实「近战可及」距离，导致进不了攻击或出手帧打空。
func _melee_plane_dist_to_target() -> float:
	if not is_instance_valid(_combat_target):
		return INF
	var a := _body.global_position
	var b := _combat_target.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()


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
		enter_state(State.LOOK)
	# 暂不巡逻：未来加入巡逻动画后再启用 PATROL
	elif randf() < 0.18:
		_pulse_look(0.12)


func _update_patrol(delta: float) -> void:
	if _can_see_combat_target():
		enter_state(State.LOOK)
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
		_anim.set_condition("idle", true)
		_anchor_pos = _body.global_position
		return
	_nav.set_target_position(_patrol_target)
	if _nav.is_navigation_finished():
		_patrol_waiting = true
		_state_timer = 0.0
		_anim.set_condition("idle", true)
		_anchor_pos = _body.global_position
		return
	EnemyMeleeLocomotion.move_toward_on_plane(
		_body,
		_nav.get_next_path_position(),
		_fp(&"move_speed", 5.0) * _PATROL_SPEED_MULT,
		delta
	)


func _update_chase(delta: float) -> void:
	# 只有当动画树真正处于 run 状态时才移动，避免“动画没切完但在滑行”
	if _anim_state_name() != "run":
		_body.velocity = Vector3.ZERO
		_body.move_and_slide()
		return
	if not is_instance_valid(_combat_target):
		enter_state(State.RETURN)
		return
	var dist: float = _body.global_position.distance_to(_combat_target.global_position)
	if dist > _fp(&"lose_target_range", 22.0):
		enter_state(State.RETURN)
		return
	var ar: float = _fp(&"attack_range", 2.0)
	var slack: float = _fp(&"attack_range_slack", 0.75)
	if _melee_plane_dist_to_target() <= ar + slack and _attack_timer <= 0.0:
		enter_state(State.ATTACK)
		return
	_nav.set_target_position(_combat_target.global_position)
	EnemyMeleeLocomotion.move_toward_on_plane(
		_body,
		_nav.get_next_path_position(),
		_fp(&"move_speed", 5.0),
		delta
	)


func _update_look(delta: float) -> void:
	if not is_instance_valid(_combat_target):
		enter_state(State.IDLE)
		return
	var dist: float = _body.global_position.distance_to(_combat_target.global_position)
	if dist > _fp(&"detection_range", 15.0):
		enter_state(State.IDLE)
		return
	_state_timer += delta
	var alert_range: float = _fp(&"alert_range", 8.0)
	if dist <= alert_range:
		enter_state(State.ALERT)
		return
	if _state_timer >= _LOOK_STATE_TIMEOUT:
		_pulse_look(0.12)
		_state_timer = 0.0


func _update_alert(delta: float) -> void:
	if not is_instance_valid(_combat_target):
		enter_state(State.IDLE)
		return
	# Screaming 时站桩但面朝向目标（仅旋转，不移动）
	var look_target := Vector3(
		_combat_target.global_position.x, _body.global_position.y, _combat_target.global_position.z
	)
	if look_target != _body.global_position:
		_body.look_at(look_target, Vector3.UP)
	var dist: float = _body.global_position.distance_to(_combat_target.global_position)
	if dist > _fp(&"detection_range", 15.0):
		enter_state(State.IDLE)
		return
	# Alert 阶段站桩播动画：当 AnimationTree 状态机真正切到 run（说明 alert 动画播完并过渡完成）才开始追击移动
	var cur: String = _anim_state_name()
	if cur == "run":
		enter_state(State.CHASE)
		return
	_state_timer += delta
	# 兜底：若动画树未启用/无 playback（或过渡条件不完整），到点后仍进入追击避免永久卡住
	if _state_timer >= _ALERT_STATE_TIMEOUT:
		enter_state(State.CHASE)


func _update_return(delta: float) -> void:
	if _can_see_combat_target():
		enter_state(State.LOOK)
		return
	_nav.set_target_position(_anchor_pos)
	if _nav.is_navigation_finished():
		enter_state(State.IDLE)
		return
	EnemyMeleeLocomotion.move_toward_on_plane(
		_body,
		_nav.get_next_path_position(),
		_fp(&"move_speed", 5.0) * _PATROL_SPEED_MULT,
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
	if _melee_plane_dist_to_target() > ar + _ATTACK_CANCEL_PLANE_EXTRA:
		_enter_chase_after_attack_timeout()
		return
	_state_timer += delta
	if _state_timer >= _ATTACK_STATE_TIMEOUT:
		_enter_chase_after_attack_timeout()


func _enter_chase_after_attack_timeout() -> void:
	_attack_timer = _fp(&"attack_cooldown", 1.2)
	_set_anim_flags(true, false, true, false, false, false)
	enter_state(State.CHASE)


func _pulse_look(seconds: float) -> void:
	if state == State.DEAD:
		return
	_anim.set_condition("look", true)
	_look_pulse_timer = maxf(_look_pulse_timer, seconds)


func _process_condition_pulses(delta: float) -> void:
	if _look_pulse_timer <= 0.0:
		return
	_look_pulse_timer = maxf(_look_pulse_timer - delta, 0.0)
	if _look_pulse_timer <= 0.0:
		_anim.set_condition("look", false)


func _set_anim_flags(run: bool, attack: bool, alert: bool, idle: bool, look: bool, die: bool) -> void:
	_anim.set_condition("run", run)
	_anim.set_condition("attack", attack)
	_anim.set_condition("alert", alert)
	_anim.set_condition("idle", idle)
	_anim.set_condition("look", look)
	if die:
		_anim.set_condition("die", true)


func _set_ai_damage_invulnerable(enabled: bool) -> void:
	var be := _body as BaseEnemy
	if be:
		be.ai_damage_invulnerable = enabled


func _is_in_intro_getup() -> bool:
	var be := _body as BaseEnemy
	return be != null and be.is_intro_getup_invulnerable()


func _anim_state_name() -> String:
	if _anim_tree == null or not is_instance_valid(_anim_tree):
		return ""
	var pb: Variant = _anim_tree.get(&"parameters/playback")
	if pb == null or not (pb is AnimationNodeStateMachinePlayback):
		return ""
	return String((pb as AnimationNodeStateMachinePlayback).get_current_node())


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
