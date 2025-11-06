extends Control

var isready
var username 

@onready var readyLabel = $Ready
@onready var usernameLabel = $UserName

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func setReady(readytext):
	readyLabel = readytext
	isready = readytext
	
func setUsername(currentUsername):
	usernameLabel = currentUsername
	username = currentUsername
