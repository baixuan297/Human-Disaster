extends Control

@onready var usertext = $MarginContainer/VBoxContainer/HBoxContainer/TextEdit
@onready var emailtext = $MarginContainer/VBoxContainer/HBoxContainer2/TextEdit2
@onready var passwdtext = $MarginContainer/VBoxContainer/HBoxContainer3/TextEdit3

func _ready():
	pass

#func _on_registrer_pressed():
	#var username = usertext.text.strip_edges()
	#var email = emailtext.text.strip_edges()
	#var passwd = passwdtext.text.strip_edges()
	# var client = Nakama.create_client("nakama_godot", "192.168.1.168", 7350, "http")

	#var session : NakamaSession = await Online.nakama_client.authenticate_email_async(email, passwd, username, true)
	#if session.is_exception():
		#print(session.get_exception().message)
	#Online.nakama_session = session
	#self.hide()
	#$"../find_match".show()
	#
#func _on_login_pressed():
	#var username = usertext.text.strip_edges()
	#var email = emailtext.text.strip_edges()
	#var passwd = passwdtext.text.strip_edges()
	#
	#var session : NakamaSession = await Online.nakama_client.authenticate_email_async(email, passwd, null, false)
	#if session.is_exception():
		#print(session.get_exception().message)
	#Online.nakama_session = session
	#self.hide()
	#$"../find_match".show()
