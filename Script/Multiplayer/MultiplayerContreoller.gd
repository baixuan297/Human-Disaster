extends Control

"""
@export var Address = "127.0.0.1"
@export var Port = 1270

var peer
# peer = ENetMultiplayerPeer.new() 如果想要立马开始游戏就对等这句

# Called when the node enters the scene tree for the first time.
func _ready():
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	
# 当有人正确连接时，服务器和客户端会调用
func peer_connected(id):
	print("Player conectado = " + str(id))

# 当有人连接失败时，服务器和客户端会调用
func peer_disconnected(id):
	
	print("Player Desconectado = " + id)

# 仅仅从客户端触发 连接服务器
func connected_to_server():
	print("connected to server!")
	SendPlayerInfo.rpc_id(1, $Panel/HBoxContainer/LineEdit.text, multiplayer.get_unique_id())

# 仅仅从客户端触发 连接失败
func connection_failed():
	print("connectd failed")

@rpc("any_peer", "call_local")
func SendPlayerInfo(name, id):
	if GameManager.Player.has(id):
		GameManager.Player[id] = {
			"name" : name,
			"id" : id,
		}
	
	if multiplayer.is_server():
		for i in GameManager.Player:
			SendPlayerInfo.rpc(GameManager.Player[i].name, i)

@rpc("any_peer", "call_local")
func StartGame():
	var scene = load("res://Scene/map/world.tscn").instantiate()
	get_tree().root.add_child(scene)
	self.hide()

func _on_host_button_down():
	peer = ENetMultiplayerPeer.new()
	# 后面的数字2 代表着几人游戏2代表两人，最多32人
	var error = peer.create_server(Port, 2)
	if error != OK:
		print("No puedo hospedar: " + error)
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	# 将我们的主机设为对等点
	multiplayer.set_multiplayer_peer(peer)
	print("Espera lo demás jugadores!")
	
	SendPlayerInfo($Panel/HBoxContainer/LineEdit.text, multiplayer.get_unique_id())
	
func _on_join_button_down():
	peer = ENetMultiplayerPeer.new()
	peer.create_client(Address, Port)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)

func _on_start_button_down():
	# rpc 代表如果房主开始了游戏，那么全部人都会进入，另一个参数rpc_id代表着指定的
	StartGame.rpc()
"""
