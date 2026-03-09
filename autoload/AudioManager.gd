extends Node3D
## 武器音效统一入口：由 WeaponManager 在射击/空仓/换弹/切枪时按需调用；
## 仅当 WeaponData.audio_data 存在时才会调用本管理器，无音效资源的武器不依赖本节点。

@export var shoot_pool_size: int = 32
@export var dry_pool_size: int = 8
@export var reload_pool_size: int = 8
@export var equip_pool_size: int = 6

var shoot_pool: AudioPool
var dry_pool: AudioPool
var reload_pool: AudioPool
var equip_pool: AudioPool


func _ready() -> void:
	# 射击
	shoot_pool = AudioPool.new()
	shoot_pool.setup(shoot_pool_size, "Weapon")
	add_child(shoot_pool)

	# 空仓
	dry_pool = AudioPool.new()
	dry_pool.setup(dry_pool_size, "Weapon")
	add_child(dry_pool)

	# 换弹
	reload_pool = AudioPool.new()
	reload_pool.setup(reload_pool_size, "Weapon")
	add_child(reload_pool)

	# 装备
	equip_pool = AudioPool.new()
	equip_pool.setup(equip_pool_size, "Weapon")
	add_child(equip_pool)


# ═══════════════════════
# 播放接口
# ═══════════════════════

func play_weapon_shoot(sound_position: Vector3, audio_data: WeaponAudioData) -> void:
	if audio_data == null:
		return

	var stream := audio_data.get_random_shoot_stream()
	var pitch := audio_data.get_random_pitch()
	var volume := audio_data.get_random_volume()

	shoot_pool.play(stream, sound_position, pitch, volume)


func play_dry_fire(sound_position: Vector3, stream: AudioStream) -> void:
	if stream == null:
		return
	dry_pool.play(stream, sound_position)


func play_reload(sound_position: Vector3, stream: AudioStream) -> void:
	if stream == null:
		return
	reload_pool.play(stream, sound_position)


func play_equip(sound_position: Vector3, stream: AudioStream) -> void:
	if stream == null:
		return
	equip_pool.play(stream, sound_position)
