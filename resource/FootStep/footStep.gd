extends Resource
class_name FootStepAudioData

# 脚步声音
@export var walk_steps: Array[AudioStream]
@export var run_steps: Array[AudioStream]
@export var crouch_sound: Array[AudioStream]


# 动作声音
@export var jump_sound: AudioStream
@export var land_sound: AudioStream

# 随机化
@export var pitch_min: float = 0.95
@export var pitch_max: float = 1.05

@export var volume_min_db: float = -1.5
@export var volume_max_db: float = 0.0
