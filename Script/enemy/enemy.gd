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
## 进入该距离后从 Look 进入 Alert，并在短暂 Alert 后开始追击
@export var alert_range:       float = 8.0

@export_group("战斗")
@export var attack_range:      float = 2.0
## 平面近战判定在 attack_range 上的额外容差（双 CharacterBody 挤开时仍应能进入攻击 / 命中）
@export var attack_range_slack: float = 0.75
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


## BaseEnemy 在「AI 免伤阶段」收到命中时调用：用于从 Look 进入 Alert
func on_ai_invulnerable_hit() -> void:
	if _fsm:
		_fsm.on_invulnerable_hit()


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

	if _fsm:
		_fsm.mark_host_dead()
	delete_collision_nodes(self)

	if stats_node and is_instance_valid(stats_node):
		stats_node.queue_free()

	await get_tree().create_timer(2.0).timeout
	queue_free()
