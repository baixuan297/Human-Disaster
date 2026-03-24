extends Control

## 角色属性面板：绑定 Player.playerStats、UserManager、GeneManager
## SYNC-1～SYNC-5：按等级区间表示同步层级；每 LEVELS_PER_SYNC_TIER 级为一个区间（到达区间末端可进行「突破」叙事）

const CLASS_ICON_DIR := "res://素材/image/CharacterMenu/AttrPanel/class/"
## FishMan 默认职业（未从 UserManager/GeneManager 获取到时使用）
const DEFAULT_CHARACTER_CLASS := "Berserk Mutant"
## SYNC 等级图标：SYNC-1～5 对应 SyncLevel1.png～SyncLevel5.png
const SYNC_ICON_DIR := "res://素材/image/CharacterMenu/AttrPanel/SYNC/"
## 每多少级进入下一档 SYNC（例如 1–5 级 SYNC-1，6–10 级 SYNC-2）
const LEVELS_PER_SYNC_TIER := 5
const SYNC_TIER_MAX := 5
## 与经验条右侧「等级上限」展示一致（内容版本上限，可按项目调整）
const DISPLAY_LEVEL_CAP := 30
## 抽象值进度条：基因点占满条所需点数（仅 UI 比例）
const ABSTRACT_POINTS_VISUAL_MAX := 100

@onready var _class_icon: TextureRect = $AttrInfo/AttrContainer/CharacterInfo/ClassIcon
@onready var _character_name: Label = $AttrInfo/AttrContainer/CharacterInfo/Character/CharacterName
@onready var _class_label: Label = $AttrInfo/AttrContainer/CharacterInfo/Character/Class
@onready var _sync_icon: TextureRect = $AttrInfo/AttrContainer/CharacterInfo/Sync/SyncIcon
@onready var _sync_level_label: Label = $AttrInfo/AttrContainer/CharacterInfo/Sync/SyncLevel
@onready var _current_level: Label = $AttrInfo/AttrContainer/LevelContainer/CurrentLevel
@onready var _level_cap_label: Label = $AttrInfo/AttrContainer/LevelContainer/ExpContainer/HBoxContainer/MaxLevel/MaxLevel
@onready var _current_exp: Label = $AttrInfo/AttrContainer/LevelContainer/ExpContainer/HBoxContainer/ExpValue/CurrentExp
@onready var _max_exp_label: Label = $AttrInfo/AttrContainer/LevelContainer/ExpContainer/HBoxContainer/ExpValue/MaxExp
@onready var _exp_progress: ProgressBar = $AttrInfo/AttrContainer/LevelContainer/ExpContainer/ExpProgress
@onready var _attr_health: Label = $AttrInfo/AttrContainer/AttrHealth/AttrValue
@onready var _attr_defense: Label = $AttrInfo/AttrContainer/AttrDefense/AttrValue
@onready var _attr_attack: Label = $AttrInfo/AttrContainer/AttrAttack/AttrValue
@onready var _attr_evasion: Label = $AttrInfo/AttrContainer/AttrEvasion/AttrValue
@onready var _abstract_value_label: Label = $AttrInfo/AttrContainer/VBoxContainer/HBoxContainer/Label2
@onready var _abstract_progress: ProgressBar = $AttrInfo/AttrContainer/VBoxContainer/ProgressBar
@onready var _desc: Label = $AttrInfo/AttrContainer/Desc
@onready var _upgrade_btn: Button = $AttrInfo/AttrContainer/Button

var _signals_bound_stats: Stats = null
## 预加载的 SYNC 图标（索引 0 = SYNC-1，对应 SyncLevel1.png）
var _sync_textures: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preload_sync_textures()
	if not GeneManager.genes_changed.is_connected(_on_genes_changed):
		GeneManager.genes_changed.connect(_on_genes_changed)
	visibility_changed.connect(_on_visibility_changed)
	_upgrade_btn.pressed.connect(_on_upgrade_button_pressed)
	_max_exp_label.visible = false
	_refresh_all()


func _on_visibility_changed() -> void:
	if visible:
		_refresh_all()


func _on_genes_changed() -> void:
	if visible:
		_refresh_all()


func _exit_tree() -> void:
	_unbind_stats_signals()


func _on_player_experience_changed(_total_exp: float, _lv: int) -> void:
	if not visible:
		return
	var stats := _get_stats()
	if stats == null:
		return
	_refresh_exp_and_health(stats)
	_refresh_sync_ui(stats)
	_refresh_health_and_combat(stats)
	_refresh_abstract_and_desc(stats)


func _on_player_health_changed(_cur: float, _maxv: float) -> void:
	if not visible:
		return
	var stats := _get_stats()
	if stats == null:
		return
	_refresh_health_and_combat(stats)


## 供角色菜单在打开「属性」页时调用
func refresh_from_player() -> void:
	_refresh_all()


func _get_player() -> Node:
	var p := SkillManager.character
	if p != null and is_instance_valid(p):
		return p
	return CharacterDataManager.get_player()


func _get_stats() -> Stats:
	var p := _get_player()
	if p == null:
		return null
	var s = p.get("playerStats")
	if s is Stats:
		return s
	return null


func _bind_stats_signals(stats: Stats) -> void:
	if stats == null or _signals_bound_stats == stats:
		return
	_unbind_stats_signals()
	_signals_bound_stats = stats
	if not stats.experience_changed.is_connected(_on_player_experience_changed):
		stats.experience_changed.connect(_on_player_experience_changed)
	if not stats.health_changed.is_connected(_on_player_health_changed):
		stats.health_changed.connect(_on_player_health_changed)


func _unbind_stats_signals() -> void:
	if _signals_bound_stats == null:
		return
	if _signals_bound_stats.experience_changed.is_connected(_on_player_experience_changed):
		_signals_bound_stats.experience_changed.disconnect(_on_player_experience_changed)
	if _signals_bound_stats.health_changed.is_connected(_on_player_health_changed):
		_signals_bound_stats.health_changed.disconnect(_on_player_health_changed)
	_signals_bound_stats = null


func _refresh_all() -> void:
	var stats := _get_stats()
	_refresh_identity()
	if stats:
		_bind_stats_signals(stats)
		_refresh_exp_and_health(stats)
		_refresh_health_and_combat(stats)
		_refresh_sync_ui(stats)
		_refresh_abstract_and_desc(stats)
	else:
		_unbind_stats_signals()
		_current_level.text = "—"
		_exp_progress.value = 0.0
		_current_exp.text = "--"
		_attr_health.text = "—"
		_attr_defense.text = "—"
		_attr_attack.text = "—"
		_attr_evasion.text = "—"
		_sync_level_label.text = "SYNC-?"
		_sync_icon.texture = null
		_abstract_value_label.text = "—"
		_abstract_progress.value = 0.0
		_desc.text = "未检测到角色属性（请进入场景并确保 Player 在组 Player 内）。"
		_upgrade_btn.disabled = true


func _refresh_identity() -> void:
	var char_name := UserManager.current_character_name
	var cls := UserManager.current_character_class
	if cls.is_empty():
		cls = GeneManager.character_class
	if char_name.is_empty():
		var p := _get_player()
		if p and p.name:
			char_name = str(p.name)
	if char_name.is_empty():
		char_name = "—"
	if cls.is_empty():
		cls = DEFAULT_CHARACTER_CLASS
	_character_name.text = char_name
	_class_label.text = cls
	_load_class_icon(cls)


func _load_class_icon(character_class: String) -> void:
	if character_class.is_empty() or character_class == "—":
		return
	var path := CLASS_ICON_DIR + character_class + ".png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex:
			_class_icon.texture = tex
	else:
		push_warning("[AttributesPanel] 未找到职业图标: %s（期望路径 %s）" % [character_class, path])


func _sync_tier_from_level(level: int) -> int:
	return clampi(1 + (level - 1) / LEVELS_PER_SYNC_TIER, 1, SYNC_TIER_MAX)


func _next_breakthrough_level(level: int) -> int:
	return int(ceil(float(level) / float(LEVELS_PER_SYNC_TIER))) * LEVELS_PER_SYNC_TIER


func _refresh_sync_ui(stats: Stats) -> void:
	var lev := stats.level
	var tier := _sync_tier_from_level(lev)
	_sync_level_label.text = "SYNC-%d" % tier
	_apply_sync_icon(tier)


func _preload_sync_textures() -> void:
	if not _sync_textures.is_empty():
		return
	for i in range(1, SYNC_TIER_MAX + 1):
		var path := "%sSyncLevel%d.png" % [SYNC_ICON_DIR, i]
		if not ResourceLoader.exists(path):
			push_warning("[AttributesPanel] 未找到 SYNC 图标: %s" % path)
			_sync_textures.append(null)
			continue
		var res = load(path)
		if res is Texture2D:
			_sync_textures.append(res)
		else:
			push_warning("[AttributesPanel] SYNC 资源不是 Texture2D: %s" % path)
			_sync_textures.append(null)


func _apply_sync_icon(tier: int) -> void:
	var idx := clampi(tier, 1, SYNC_TIER_MAX) - 1
	if _sync_textures.is_empty():
		_preload_sync_textures()
	if idx >= _sync_textures.size():
		return
	var t = _sync_textures[idx]
	if t is Texture2D:
		_sync_icon.texture = t


func _exp_segment_bounds(level: int, base_exp: float) -> Vector2:
	## 与 Stats.level 的 sqrt 公式一致：level = floor(max(1, sqrt(exp/base)+0.5))
	if level <= 1:
		return Vector2(0.0, pow(1.5, 2.0) * base_exp)
	var lo := pow(float(level) - 0.5, 2.0) * base_exp
	var hi := pow(float(level) + 0.5, 2.0) * base_exp
	return Vector2(lo, hi)


func _refresh_exp_and_health(stats: Stats) -> void:
	var lev := stats.level
	_current_level.text = str(lev)
	_level_cap_label.text = str(DISPLAY_LEVEL_CAP)
	var base := stats.base_exp_to_next_level
	var seg := _exp_segment_bounds(lev, base)
	var lo := seg.x
	var hi := seg.y
	var experience := stats.experience
	var span := maxf(hi - lo, 1.0)
	var t := clampf((experience - lo) / span, 0.0, 1.0)
	_exp_progress.max_value = 100.0
	_exp_progress.value = t * 100.0
	_current_exp.text = "%d / %d" % [int(floor(experience)), int(floor(hi))]


## 生命 + 攻防闪：全部使用 Stats 上「当前结算后的」数值（含等级曲线、基因、Buff）
## 生命行显示「当前/最大」，受击时能及时反映变化
func _refresh_health_and_combat(stats: Stats) -> void:
	_attr_health.text = "%d / %d" % [int(floor(stats.current_health)), int(floor(stats.current_max_health))]
	_attr_defense.text = str(int(round(stats.current_defense)))
	_attr_attack.text = str(int(round(stats.current_attack)))
	_attr_evasion.text = "%.1f%%" % (stats.current_evasion * 100.0)


func _refresh_abstract_and_desc(stats: Stats) -> void:
	var points := GeneManager.gene_points
	_abstract_value_label.text = str(points)
	_abstract_progress.max_value = 100.0
	_abstract_progress.value = clampf(float(points) / float(ABSTRACT_POINTS_VISUAL_MAX), 0.0, 1.0) * 100.0
	var lev := stats.level
	var tier := _sync_tier_from_level(lev)
	var next_brk := _next_breakthrough_level(lev)
	if lev > 0 and lev % LEVELS_PER_SYNC_TIER == 0:
		_desc.text = "已到达 SYNC-%d 阶段边界。可进行同步突破以稳固意识链接，并解锁更高同步层级。" % tier
		_upgrade_btn.disabled = false
		_upgrade_btn.text = "突破"
	else:
		_desc.text = "当前同步层级：SYNC-%d。下一建议突破等级：%d。" % [tier, next_brk]
		_upgrade_btn.disabled = true
		_upgrade_btn.text = "升级"


func _on_upgrade_button_pressed() -> void:
	## 占位：后续可接突破流程（任务 / 消耗 / API）
	print("[AttributesPanel] 突破按钮（待接游戏逻辑），当前仅刷新显示")
	_refresh_all()
