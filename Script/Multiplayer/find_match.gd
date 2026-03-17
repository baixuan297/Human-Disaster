extends Control

@onready var findmatch = $FindMatch
@onready var findinglabel = $Label

## Called when the node enters the scene tree for the first time.
#func _ready():
	#OnlineMatch.connect("player_joined", Callable(self, "OnMatchFound"))
	#
#func OnMatchFound(players):
	#print(players)
	#hide()
	#$"../user_ready_screen".show()
#
#func _on_find_match_pressed():
	#findmatch.hide()
	#findinglabel.show()
	#
	#if not Online.is_nakama_socket_connected():
		#Online.connect_nakama_socket()
		#await Online.socket_connected
	#print("Looking for match...")
	#var data = {
		#min_count = 2
	#}
	#OnlineMatch.start_matchmaking(Online.nakama_socket, data)
	
