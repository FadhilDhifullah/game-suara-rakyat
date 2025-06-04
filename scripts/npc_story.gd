extends CharacterBody2D

@export var npc_texture: Texture
@export var dialog_data: Array = []


var is_player_near: bool = false
var player_node: Node2D = null

func _ready() -> void:
	if dialog_data.is_empty():
		var npc_name = name
		var file_path = "res://scripts/dialogs/dialog_" + npc_name.to_lower() + ".json"
		if FileAccess.file_exists(file_path):
			var file = FileAccess.open(file_path, FileAccess.READ)
			var json_str = file.get_as_text()
			var json = JSON.new()
			var err = json.parse(json_str)
			if err == OK and json.data is Array:
				dialog_data = json.data
				print("[npc_story] Dialog loaded from JSON: ", file_path)
			else:
				print("[npc_story] File JSON rusak atau formatnya salah:", err)
		else:
			print("[npc_story] Dialog JSON tidak ditemukan: ", file_path)
		print("[npc_story] dialog_data: ", dialog_data)

	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)

	player_node = get_tree().get_current_scene().get_node("Player")
	print("[npc_story] player_node = ", player_node)

func _on_body_entered(body: Node) -> void:
	print("[npc_story] Player masuk:", body)
	if body == player_node:
		is_player_near = true

func _on_body_exited(body: Node) -> void:
	print("[npc_story] Player keluar:", body)
	if body == player_node:
		is_player_near = false

func _input(event: InputEvent) -> void:
	if is_player_near and event.is_action_pressed("ui_select"):
		print("[npc_story] ui_select ditekan.")
		var dm = get_tree().get_current_scene().get_node("DialogueManager")
		print("[npc_story] Hasil get_node DialogueManager: ", dm)
		if dm:
			dm.start_dialogue(self)
		else:
			print("[npc_story] ERROR: DialogueManager tidak ditemukan!")
