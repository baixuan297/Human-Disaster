## 三维物理层位掩码（与 project.godot 中 [layer_names] 一一对应）
## 使用方式：collision_layer = CollisionLayers.LAYER_CHARACTER
##          collision_mask = CollisionLayers.MASK_PLAYER_MOVE
class_name CollisionLayers
extends RefCounted

# ── 单层（第 n 层 → 位 (n-1)）────────────────────────────────────────────
const LAYER_WORLD: int = 1 << 0 ## 1 — 地形、静态障碍、可行走表面
const LAYER_CHARACTER: int = 1 << 1 ## 2 — 玩家与敌人的 CharacterBody3D 主体
const LAYER_HURTBOX: int = 1 << 2 ## 4 — 受击判定 Area3D（部位 hurtbox）
const LAYER_SKILL_AREA: int = 1 << 3 ## 8 — 技能/危害等范围检测体（可选）
const LAYER_PICKUP: int = 1 << 4 ## 16 — 可拾取物（武器等）
const LAYER_PHYSICS_PROP: int = 1 << 5 ## 32 — 可推动刚体、场景机关
const LAYER_INTERACTABLE: int = 1 << 6 ## 64 — 门、终端等可交互
const LAYER_GAMEPLAY_VOLUME: int = 1 << 7 ## 128 — 玩法触发体积、相机相关等
const LAYER_TUTORIAL: int = 1 << 8 ## 256 — 教程区触发、教程传送等（第 9 命名层；宝箱见 **Interactable**）

# ── 常用组合 mask（检测目标）──────────────────────────────────────────────
## 子弹 / 瞄准：命中角色碰撞体或 hurtbox
const MASK_BULLET: int = LAYER_CHARACTER | LAYER_HURTBOX
## 第一/三人称武器瞄准射线（技能指示、点选敌人）
const MASK_AIM_TARGET: int = LAYER_CHARACTER | LAYER_HURTBOX
## 技能范围仅检测角色刚体（body_entered）
const MASK_SKILL_BODY: int = LAYER_CHARACTER
## 仅地面 / 静态几何
const MASK_WORLD: int = LAYER_WORLD
## 玩家移动：地面、角色挤推、拾取、刚体、可交互、玩法触发体积（与 Area3D 双向检测需 mask 含对方 layer）
const MASK_PLAYER_MOVE: int = (
	LAYER_WORLD	| LAYER_CHARACTER
	| LAYER_PICKUP
	| LAYER_PHYSICS_PROP
	| LAYER_INTERACTABLE
	| LAYER_GAMEPLAY_VOLUME
	| LAYER_TUTORIAL
)
## 鼠标指向技能目标：地表或角色/受击盒（避免 PhysicsRayQuery 默认全层拾取误挡）
const MASK_SKILL_MOUSE_RAY: int = LAYER_WORLD | LAYER_CHARACTER | LAYER_HURTBOX
## 交互射线（FPCamera Interactable）：世界、角色、拾取物、可交互、玩法体积（宝箱、门等均在 **Interactable**）
const MASK_INTERACT_RAY: int = (
	LAYER_WORLD
	| LAYER_CHARACTER
	| LAYER_PICKUP
	| LAYER_INTERACTABLE
	| LAYER_GAMEPLAY_VOLUME
)
## 捡物/刚体拾取短射线：地面、可拾取刚体、场景刚体
const MASK_PICKUP_RAY: int = LAYER_WORLD | LAYER_PICKUP | LAYER_PHYSICS_PROP
## 敌人 CharacterBody：站立与移动
const MASK_ENEMY_MOVE: int = LAYER_WORLD | LAYER_CHARACTER | LAYER_PHYSICS_PROP
## 玩家根节点 collision_layer：角色 + 可交互 + 玩法体积
const LAYER_PLAYER_BODY: int = LAYER_CHARACTER | LAYER_INTERACTABLE | LAYER_GAMEPLAY_VOLUME
