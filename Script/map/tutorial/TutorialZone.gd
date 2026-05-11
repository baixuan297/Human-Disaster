extends Area3D
## 教程触发器：玩家身体进入时推进到指定步骤（如解锁蹲、跳、奔跑）。
## 在编辑器中设置 step 为 TutorialManager.Step 枚举值。

@export var step: TutorialManager.Step = TutorialManager.Step.JUMP_CROUCH


func _ready() -> void:
	collision_layer = CollisionLayers.LAYER_TUTORIAL
	collision_mask = CollisionLayers.LAYER_PLAYER_BODY
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		TutorialManager.advance_to_step(step)
