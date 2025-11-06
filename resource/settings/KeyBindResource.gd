class_name KeyBindResource
extends Resource

const MOVE_LEFT = "move_left"
const MOVE_RIGHT = "move_right"
const MOVE_FORWARD = "move_forward"
const MOVE_BACKWARD = "move_back"
const RUN = "Run"
const JUMP = "jump"
const CROUCH = "crouch"
const FREELOOK = "free_look"
const CHANGEPERSON = "change_person"
const CHANGEWEAPON1 = "change_weapon1"
const CHANGEWEAPON2 = "change_weapon2"

@export var DEFAULT_MOVE_RIGHT_KEY = InputEventKey.new()
@export var DEFAULT_MOVE_LEFT_KEY = InputEventKey.new()
@export var DEFAULT_MOVE_FORWARD_KEY = InputEventKey.new()
@export var DEFAULT_MOVE_BACKWARD_KEY = InputEventKey.new()
@export var DEFAULT_RUN_KEY = InputEventKey.new()
@export var DEFAULT_CROUCH_KEY = InputEventKey.new()
@export var DEFAULT_JUMP_KEY = InputEventKey.new()
@export var DEFAULT_FREELOOK_KEY = InputEventKey.new()
@export var DEFAULT_CHANGEPERSON_KEY = InputEventKey.new()
@export var DEFAULT_CHANGEWEAPON1_KEY = InputEventKey.new()
@export var DEFAULT_CHANGEWEAPON2_KEY = InputEventKey.new()

var move_left_key = InputEventKey.new()
var move_right_key = InputEventKey.new()
var move_forward_key = InputEventKey.new()
var move_backward_key = InputEventKey.new()
var run_key = InputEventKey.new()
var crouch_key = InputEventKey.new()
var jump_key = InputEventKey.new()
var freelook_key = InputEventKey.new()
var change_person_key = InputEventKey.new()
var change_weapon1_key = InputEventKey.new()
var change_weapon2_key = InputEventKey.new()
