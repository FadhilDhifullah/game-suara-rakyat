extends Area2D
class_name Doors

@export var destination_level_tag: String
@export var destination_door_tag: String
@export var spawn_diraction := "up"

@onready var spawn = $Spawn

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	print("Body entered door:", body)
	if body is Player:
		print("It's the player! Going to level...")
		NavigationManager.go_to_level(destination_level_tag, destination_door_tag)
