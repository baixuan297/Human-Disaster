extends Node3D
class_name AudioPool
## 3D 音效池：轮询复用 AudioStreamPlayer3D，stream 为 null 时不播放。

var players: Array[AudioStreamPlayer3D] = []
var pool_size: int
var index: int = 0

func setup(size: int, bus_name: String = "Master") -> void:
	pool_size = size
	
	for i in pool_size:
		var p := AudioStreamPlayer3D.new()
		p.bus = bus_name
		add_child(p)
		players.append(p)

func play(
	stream: AudioStream,
	sound_position: Vector3,
	pitch: float = 1.0,
	volume_db: float = 0.0
) -> void:
	if stream == null:
		return
	
	var player := players[index]
	player.global_position = sound_position
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()

	index = (index + 1) % pool_size
