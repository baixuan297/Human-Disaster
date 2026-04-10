extends BaseEnemy

## enemy.gd — 通用近战敌人（薄封装）
##
## 逻辑拆分：`EnemyMeleeFsm`（状态机）、`EnemyMeleeLocomotion`（移动）、`EnemyAnimationConditions`（动画条件）、
## `EnemyCombatTargeting`（目标）、`EnemyAiProfileBinding`（静态数据覆盖导出参数）。
## AnimationTree Method Track 仍绑定本节点上的 `_hit_finished()`。

# ── 可配置参数（与 EnemyMeleeFsm / EnemyAiProfileBinding 键名一致）────────────────

@export_group("移动")
@export var move_speed:        float = 5.0
@export var patrol_radius:     float = 8.0
@export var patrol_wait_time:  float = 2.5

@export_group("感知")
@export var detection_range:   float = 15.0
@export var lose_target_range: float = 22.0

@export_group("战斗")
@export var attack_range:      float = 2.0
@export var attack_cooldown:   float = 1.2
@export var stun_on_hit_chance: float = 0.25
@export var stun_duration:     float = 0.8
@export var base_damage:       float = 10.0


# ── 节点引用 ──────────────────────────────────────────────────────────────────

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree     = $AnimationTree


# ── 组合 ───────────────────────────────────────────────────────────────────────

var _fsm: EnemyMeleeFsm
var _is_dead: bool = false


func _ready() -> void:
	super._ready()

	_fsm = EnemyMeleeFsm.new()
	_fsm.setup(self, nav_agent, anim_tree)

	call_deferred("_bind_ai_profile")
	call_deferred("_log_ai_routing_once")


func _bind_ai_profile() -> void:
	EnemyAiProfileBinding.apply_from_template_id(self, enemy_template_id)


func _process(delta: float) -> void:
	if stats:
		stats.process_effects(delta)
	if _fsm:
		_fsm.process_tick(delta)


# ── 公共接口 ──────────────────────────────────────────────────────────────────

func apply_stun(duration: float) -> void:
	if _fsm:
		_fsm.apply_stun(duration)


func on_received_damage() -> void:
	if _fsm:
		_fsm.on_received_damage()


## AnimationTree Method Track — 攻击命中帧
func _hit_finished() -> void:
	if _fsm:
		_fsm.on_hit_finished()


# ── BaseEnemy 重写 ────────────────────────────────────────────────────────────

func _on_health_changed(current_health: float, maximum_health: float) -> void:
	super._on_health_changed(current_health, maximum_health)
	on_received_damage()


func _on_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	apply_kill_rewards()

	print("💀 [%s] 死亡" % name)
	if _fsm:
		_fsm.mark_host_dead()
	delete_collision_nodes(self)

	if stats_node and is_instance_valid(stats_node):
		stats_node.queue_free()

	await get_tree().create_timer(2.0).timeout
	queue_free()


# ── 调试 / 数据 ───────────────────────────────────────────────────────────────

func _log_ai_routing_once() -> void:
	if enemy_template_id <= 0:
		return
	if not GameDataManager.is_loaded():
		if not GameDataManager.all_data_loaded.is_connected(_log_ai_routing_once):
			GameDataManager.all_data_loaded.connect(_log_ai_routing_once, CONNECT_ONE_SHOT)
		return
	var def: Dictionary = GameDataManager.get_enemy(enemy_template_id)
	if EnemyBehaviorBrain.wants_behavior_tree(def) and EnemyBehaviorBrain.fallback_fsm_when_bt_missing(def):
		var bt: String = EnemyBehaviorBrain.get_behavior_tree_id(def)
		print("[enemy] template=%s 已配置行为树/ bt 包，当前仍由 FSM 兜底，BT id=%s" % [enemy_template_id, bt])
