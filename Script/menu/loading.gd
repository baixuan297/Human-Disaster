extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var video_stream_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var tips_label: Label = $TipsLabel
@onready var timer: Timer = $Timer
@onready var fade_texture: ColorRect = $fadeTexture
@onready var background_image: TextureRect = $BackgroundImage

var next_scene: String = ""
var progress: Array
var update: float = 0.0
var loading_video: Array = ["core", "fleet", "black_hole"]
var loading_image: Array = ["core", "fleet", "black_hole", "gun", "plane"]
var tips = [
	"提示：按 Shift 键可以加速跑步",
	"提示：经常保存游戏可以避免损失进度",
	"提示：注意子弹储备",
	"提示：不同角色有不同技能",
	"提示：数字键可以切换武器"
]
var tween: Tween

func _ready() -> void:
	play_fade_in()
	
	# 加载场景实例化
	next_scene = SceneManager.get_load_scene_path()
	if next_scene.is_empty():
		# 错误返还回调
		SceneManager.on_scene_load_failed()
		return
		
	ResourceLoader.load_threaded_request(next_scene)

	# 随机化
	randomize()
	# 加载提示
	tips_label.text = get_random_tip()
	timer.start()
	
	# 50%的概率使用视频或者图片
	_setup_bg()
	
func _setup_bg() -> void:
	var use_video := randf() < 0.5
	
	if use_video:
		# 加载随机背景视频
		var random_video: String = loading_video[randi() % loading_video.size()]
		var video_path: String = get_loading_video_path(random_video)
		video_stream_player.stream = load(video_path)
		video_stream_player.visible = true
		#background_image.texture = null
		background_image.visible = false
		video_stream_player.play()
	else:
		# 加载随机背景图片
		var random_image: String = loading_image[randi() % loading_image.size()]
		var image_path: String = get_loading_image_path(random_image)
		background_image.texture = load(image_path)
		background_image.visible = true
		#video_stream_player.stream = null
		video_stream_player.visible = false
	
func _process(delta: float) -> void:
	# 获取当前异步加载的状态， 并且将加载进度保存到progress中 范围是0.0-1.0
	var result = ResourceLoader.load_threaded_get_status(next_scene, progress)
	# 如果出错了，返回到上一个场景
	if result == ResourceLoader.THREAD_LOAD_FAILED:
		SceneManager.on_scene_load_failed()
		return
	
	# 如果当前加载进度大于之前记录的update就更新它。update 相当于记录当前加载的最远进度。
	if progress[0] > update:
		update = progress[0]
		# 通知管理器进度更新
		SceneManager.loading_progress.emit(update)
		
	if progress_bar.value >= 0.85:
		play_fade_out()
	
	# 当资源加载好了，就切换到目标场景。
	if progress_bar.value >= 1.0 and result == ResourceLoader.THREAD_LOAD_LOADED:
			#get_tree().change_scene_to_packed(
				#ResourceLoader.load_threaded_get(next_scene)
			#)
		_switch_to_loaded_scene()
		return
		
	# 平滑移动进度条
	if progress_bar.value < update:
		progress_bar.value = lerp(progress_bar.value, update, delta)
	# 如果卡住了开始进行虚拟进度推进，为了增加体验:)
	progress_bar.value += delta * 0.2 * \
		(2.0 if update >= 1.0 else clamp(0.9 - progress_bar.value, 0.0, 1.0))
	
	# progress_label.text = str(int(progress_bar.value * 100.0)) + "%"

func _switch_to_loaded_scene() -> void:
	# 获取加载好的场景资源
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(next_scene)
	
	if not packed_scene:
		push_error("无法获取已加载的场景")
		SceneManager.on_scene_load_failed()
		return
	
	# 实例化新场景
	var new_scene = packed_scene.instantiate()
	
	# 通知管理器场景加载完成
	SceneManager.on_scene_loaded(new_scene)
	
	# 切换场景
	get_tree().change_scene_to_packed(packed_scene)

func get_loading_video_path(loading_video_name):
	match loading_video_name:
		"core":
			return "res://素材/video/Loading/blackHole.ogv" # **
		"black_hole":
			return "res://素材/video/Loading/blackHole.ogv"
		"fleet":
			return "res://素材/video/Loading/fleet.ogv"

func get_loading_image_path(loading_image_name):
	match loading_image_name:
		"core":
			return "res://素材/image/loading/core.jpg"
		"black_hole":
			return "res://素材/image/loading/black_hole.jpg"
		"fleet":
			return "res://素材/image/loading/fleet.jpg"
		"gun":
			return "res://素材/image/loading/gun.jpg"
		"plane":
			return "res://素材/image/loading/plane.jpg"

func get_random_tip() -> String:
	return tips[randi() % tips.size()]

func _on_timer_timeout() -> void:
	tips_label.text = get_random_tip()

func play_fade_in():
	# 在场景中添加一个tween
	tween = get_tree().create_tween()
	# 将fade texture加入到tween的属性编辑中，通过动画改变他的颜色透明度。
	# 使用正弦曲线作为过渡函数，这个函数有个平滑过渡效果，最后设置动画开始和结束都慢，中间加速
	tween.tween_property(fade_texture, "modulate:a", 0.0, 1.0) \
						.set_trans(Tween.TRANS_SINE) \
						.set_ease(Tween.EASE_IN_OUT)
	
func play_fade_out():
	#tween = get_tree().create_tween()
	#tween.tween_property(fade_texture, "modulate:a", 1.0, 1.0) 
	if tween:
		tween.kill()
	
	tween = get_tree().create_tween()
	tween.tween_property(fade_texture, "modulate:a", 1.0, 1.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
