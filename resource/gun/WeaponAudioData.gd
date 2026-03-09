extends Resource
class_name WeaponAudioData

# ═════════════════════════════════════════════
# 射击音效
# ═════════════════════════════════════════════

## 射击音效变体（建议 3~6 个）
@export var shoot_variations : Array[AudioStream]

## Pitch 随机范围
@export var pitch_min : float = 0.96
@export var pitch_max : float = 1.04

## 音量随机范围
@export var volume_min_db : float = -1.0
@export var volume_max_db : float = 0.0


# ═════════════════════════════════════════════
# 其他基础音效
# ═════════════════════════════════════════════

## 空仓音
@export var dry_fire_stream : AudioStream

## 换弹音
@export var reload_stream : AudioStream

## 装备武器音（切枪）
@export var equip_stream : AudioStream


# ═════════════════════════════════════════════
# 工具函数
# ═════════════════════════════════════════════

func get_random_shoot_stream() -> AudioStream:
	if shoot_variations.is_empty():
		return null
	return shoot_variations.pick_random()

func get_random_pitch() -> float:
	return randf_range(pitch_min, pitch_max)

func get_random_volume() -> float:
	return randf_range(volume_min_db, volume_max_db)
