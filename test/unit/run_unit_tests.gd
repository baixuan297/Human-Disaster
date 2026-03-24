extends SceneTree
## 无头单元测试入口（不依赖 GUT）
##
## 运行（PowerShell，需已安装 Godot 4 且可在 PATH 中调用 godot）：
##   godot --path "Human Disaster" --headless -s res://test/unit/run_unit_tests.gd
##
## 退出码：0 全部通过，1 有失败

const _SEP := "════════════════════════════════════════"

var _failed: int = 0


func _init() -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_and_quit")


func _run_and_quit() -> void:
	_run_all()
	quit(1 if _failed > 0 else 0)


func _run_all() -> void:
	# 数据驱动：新增用例只需往数组追加 { "fn", "label" }
	var suite: Array[Dictionary] = [
		{"fn": _test_hazard_creates_hazard_attack, "label": "Hazard.create_attack_data → AttackData HAZARD"},
		{"fn": _test_hazard_type_matches_subtype, "label": "HazardType 与 hazard_sub_type 一致"},
		{"fn": _test_attackdata_hazard_name, "label": "get_hazard_type_name 毒/火"},
		{"fn": _test_create_hazard_attack_static, "label": "AttackData.create_hazard_attack 静态工厂"},
	]
	for item in suite:
		var fn: Callable = item["fn"]
		_check(fn.call(), item["label"])

	print(_SEP)
	if _failed == 0:
		print("  Godot unit tests: 全部通过")
	else:
		push_error("  Godot unit tests: %d 项失败" % _failed)
	print(_SEP)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("[ OK ] " + label)
	else:
		_failed += 1
		push_error("[FAIL] " + label)


## 共享：由 Hazard 配置生成 AttackData 并校验 HAZARD 源与伤害
func _expect_hazard_attack(
	hazard_type: Hazard.HazardType,
	damage: float,
) -> bool:
	var h := Hazard.new()
	h.hazard_type = hazard_type
	h.damage = damage
	h.tick_interval = 0.5
	var atk: AttackData = h.create_attack_data(null)
	if atk == null:
		return false
	if atk.source != AttackData.AttackType.HAZARD:
		return false
	if not is_equal_approx(atk.base_damage, damage) or not is_equal_approx(atk.final_damage, damage):
		return false
	return atk.hazard_sub_type == int(hazard_type)


func _test_hazard_creates_hazard_attack() -> bool:
	return _expect_hazard_attack(Hazard.HazardType.POISON, 12.5)


func _test_hazard_type_matches_subtype() -> bool:
	return _expect_hazard_attack(Hazard.HazardType.FIRE, 3.0)


func _test_attackdata_hazard_name() -> bool:
	var a := AttackData.create_hazard_attack(5.0, null, int(Hazard.HazardType.POISON))
	var b := AttackData.create_hazard_attack(5.0, null, int(Hazard.HazardType.FIRE))
	return a.get_hazard_type_name() == "毒" and b.get_hazard_type_name() == "火"


func _test_create_hazard_attack_static() -> bool:
	var atk := AttackData.create_hazard_attack(7.0, null, -1)
	return (
		atk.source == AttackData.AttackType.HAZARD
		and is_equal_approx(atk.final_damage, 7.0)
		and atk.hazard_sub_type == -1
	)
