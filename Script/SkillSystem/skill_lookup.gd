## SkillLookup — 技能名字符串规范化 + 同义词表（纯工具类，无具体技能知识）
##
## 使用方式：
## - `register_synonym(alias, canonical_runtime_name)`：注册别名（ASCII 会自动补 `to_lower` 映射）。
## - `normalize_lookup_key(key)`：把任意来源的字符串映射到 canonical；未命中则返回 `strip_edges` 结果。
## - `reset()`：在新一轮 autoload 启动 / 切号时清表，避免 static 状态跨会话残留。
##
## 具体技能的别名由 `SkillResourceRegistry` 在 `_ready` 或数据库回调里动态写入，本类不内置任何技能名。
class_name SkillLookup
extends RefCounted

static var _synonym_to_canonical: Dictionary = {}


## 注册任意显示名 / 旧键 / skill_id 字符串 → 运行时 canonical（与 SkillResource.skill_name 一致）
static func register_synonym(alias: String, canonical_runtime_name: String) -> void:
	var a := alias.strip_edges()
	var c := canonical_runtime_name.strip_edges()
	if a.is_empty() or c.is_empty():
		return
	_synonym_to_canonical[a] = c
	if _alias_is_ascii_foldable(a):
		_synonym_to_canonical[a.to_lower()] = c


static func _alias_is_ascii_foldable(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 127:
			return false
	return true


## 将任意来源的技能名字符串规范为 SkillManager.skills 字典键。
## 未命中时返回去空白后的原串，让调用方决定是否 push_warning。
static func normalize_lookup_key(key: String) -> String:
	var k := key.strip_edges()
	if k.is_empty():
		return k
	if _synonym_to_canonical.has(k):
		return str(_synonym_to_canonical[k])
	var kl := k.to_lower()
	if _synonym_to_canonical.has(kl):
		return str(_synonym_to_canonical[kl])
	return k


## 清空同义词表（static 数据在编辑器 play 多次时会残留，必要时显式重置）。
static func reset() -> void:
	_synonym_to_canonical.clear()


## 调试：原始输入与规范化结果
static func format_lookup_attempt(raw: String) -> String:
	var nk := normalize_lookup_key(raw)
	var stripped := raw.strip_edges()
	if nk == stripped:
		return "「%s」" % raw
	return "「%s」→「%s」" % [raw, nk]


## 调试：导出当前已登记别名数量（不含值去重）
static func synonym_count() -> int:
	return _synonym_to_canonical.size()
