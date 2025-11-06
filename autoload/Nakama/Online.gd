extends Node

# For developers to set from the outside, for example:
#   Online.nakama_host = 'nakama.example.com'
#   Online.nakama_scheme = 'https'
@export var nakama_server_key: String = 'nakama_godot'
@export var nakama_host: String = '192.168.1.168'
@export var nakama_port: int = 7350
@export var nakama_scheme: String = 'http'

# For other scripts to access:
@onready var nakama_client : NakamaClient: get = get_nakama_client, set = _set_readonly_variable_client
@onready var nakama_session : NakamaSession: set = set_nakama_session
# , get = _get_session
var nakama_socket : NakamaSocket = null : set = _set_readonly_variable
	
# Internal variable for initializing the socket.
var _nakama_socket_connecting := false

signal session_changed (nakama_session)
signal session_connected (nakama_session)
signal socket_connected (nakama_socket)

func _set_readonly_variable(_value) -> void:
	nakama_socket = _value
	pass

func _set_readonly_variable_client(_value) -> void:
	nakama_client = _value
	pass
func _set_readonly_variable_socket(_value) -> void:
	nakama_socket = _value
	pass

func _get_session():
	return nakama_session

func _ready() -> void:
	# Don't stop processing messages from Nakama when the game is paused.
	# Nakama.pause_mode = Node.PROCESS_MODE_PAUSABLE
	Nakama.set_process_mode(Node.PROCESS_MODE_PAUSABLE)
	pass

func get_nakama_client() -> NakamaClient:
	if nakama_client == null:
		nakama_client = Nakama.create_client(
			nakama_server_key,
			nakama_host,
			nakama_port,
			nakama_scheme,
			Nakama.DEFAULT_TIMEOUT,
			NakamaLogger.LOG_LEVEL.ERROR)
	return nakama_client
	
func set_nakama_session(_nakama_session: NakamaSession) -> void:
	nakama_session = _nakama_session

	emit_signal("session_changed", nakama_session)

	if nakama_session and not nakama_session.is_exception() and not nakama_session.is_expired():
		emit_signal("session_connected", nakama_session)

func connect_nakama_socket() -> void:
	if nakama_socket != null:
		return
	if _nakama_socket_connecting:
		return
	_nakama_socket_connecting = true

	var new_socket : NakamaSocket = Nakama.create_socket_from(nakama_client)
	await new_socket.connect_async(nakama_session)
	nakama_socket = new_socket
	_nakama_socket_connecting = false
	emit_signal("socket_connected", nakama_socket)


func is_nakama_socket_connected() -> bool:
	return nakama_socket != null && nakama_socket.is_connected_to_host()
