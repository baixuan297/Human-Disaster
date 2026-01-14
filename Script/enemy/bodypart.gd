extends Area3D
class_name EnemyBodyPart

enum BodyPart {
	HEAD,
	BODY,
	LIMB,
}

@export var body_part: BodyPart = BodyPart.BODY

signal body_part_hit(attack_data: AttackData)

func enemy_hit(attack_data: AttackData) -> void:
	if attack_data == null:
		return

	# 只记录命中部位，不计算
	match body_part:
		BodyPart.HEAD:
			attack_data.body_part_multiplier = 2.0
		BodyPart.BODY:
			attack_data.body_part_multiplier = 1.0
		BodyPart.LIMB:
			attack_data.body_part_multiplier = 0.5
	body_part_hit.emit(attack_data)
