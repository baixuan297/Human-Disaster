#extends Area3D
#class_name HurtBox
#
#enum BodyPart {
	#HEAD,
	#BODY,
	#LIMB,
#}
#
### 信号
#
#
#@export var body_part: BodyPart = BodyPart.BODY
#
#signal body_part_hit(attack_data: AttackData)
#
#func enemy_hit(attack_data: AttackData) -> void:
	#if attack_data == null:
		#return
#
	## 只记录命中部位，不计算
	#match body_part:
		#BodyPart.HEAD:
			#attack_data.body_part_multiplier = 2.0
		#BodyPart.BODY:
			#attack_data.body_part_multiplier = 1.0
		#BodyPart.LIMB:
			#attack_data.body_part_multiplier = 0.5
	#body_part_hit.emit(attack_data)

extends Area3D
class_name EnemyBodyPart

## 敌人身体部位 - 命中检测与倍率应用
enum BodyPart {
	HEAD,
	BODY,
	LIMB,
}

@export var body_part: BodyPart = BodyPart.BODY

signal body_part_hit(attack_data: AttackData)


## 命中处理（关键修改）
func enemy_hit(attack_data: AttackData) -> void:
	if attack_data == null:
		push_error("EnemyBodyPart: 收到空的 AttackData")
		return
	
	# ──────────────────────────────────────────────────────────
	# 1. 根据部位设置倍率
	# ──────────────────────────────────────────────────────────
	var multiplier: float = 1.0
	match body_part:
		BodyPart.HEAD:
			multiplier = 2.0
		BodyPart.BODY:
			multiplier = 1.0
		BodyPart.LIMB:
			multiplier = 0.5
	
	# ──────────────────────────────────────────────────────────
	# 2. 【关键】调用 AttackData 的方法应用倍率
	# ──────────────────────────────────────────────────────────
	attack_data.apply_body_part_multiplier(multiplier)
	
	# ──────────────────────────────────────────────────────────
	# 3. 发射信号通知敌人主体
	# ──────────────────────────────────────────────────────────
	body_part_hit.emit(attack_data)

	if OS.is_debug_build():
		print("🎯 命中部位: %s | 倍率: %.1fx | 最终伤害: %.1f" % [
			BodyPart.keys()[body_part],
			multiplier,
			attack_data.final_damage
		])
