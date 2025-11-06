extends Control

var readyline = preload("res://Scene/Multiplayer/user_ready.tscn")
@onready var readyline_container = $VBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready():
	OnlineMatch.connect("player_joined", PlayerJoined)
	OnlineMatch.connect("player_left", PlayerLeft)
	OnlineMatch.connect("player_status_changed", PlayerStatusChanged)
	OnlineMatch.connect("match_ready", MatchReady)
	OnlineMatch.connect("match_not_ready", MatchNotReady)
	OnlineMatch.connect("player_joined", AddPlayers)

func AddPlayers(players):
	for id in players:
		var status = readyline.instantiate()
		readyline_container.add_child(readyline)
		readyline.setUsername(players[id]["username"])
		
func PlayerJoined(player):
	pass

func PlayerLeft(player):
	pass
	
func PlayerStatusChanged(player, status):
	pass
	
func MatchReady(player):
	pass
	
func MatchNotReady(player):
	pass

func _on_button_pressed():
	pass # Replace with function body.
