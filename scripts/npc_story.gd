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
	if body == player_node:
		is_player_near = true

func _on_body_exited(body: Node) -> void:
	if body == player_node:
		is_player_near = false

func _input(event: InputEvent) -> void:
	if is_player_near and event.is_action_pressed("ui_select"):
		var dm = get_tree().get_current_scene().get_node("DialogueManager")
		var npc_key = GameState.normalize_name(name)
		print("[npc_story] Interact attempt:", name, "as", npc_key)

		# --- CEK SUDAH INTERAKSI BELUM? ---
		if GameState.taken_by_player.has(npc_key):
			if dm and dm.has_method("show_rejection"):
				dm.show_rejection("%s: Kamu sudah pernah berinteraksi." % name, self)
			else:
				print("%s: Kamu sudah pernah berinteraksi." % name)
			return
		# --- END SUDAH INTERAKSI ---

		# --- CEK BIAS DI SINI ---
		var meta = GameState.NPC_META.get(npc_key, null)
		if meta != null:
			var total_suara = GameState.player_pop + GameState.player_elit
			if total_suara >= 20:
				var cur_bias = GameState.bias(GameState.player_pop, GameState.player_elit)
				if meta.pref == "elitis" and cur_bias >= meta.bias_limit:
					# Tambahkan NPC ke taken_by_player dengan "ilfeel"
					GameState.taken_by_player[npc_key] = "ilfeel"
					# Emit sinyal agar HUD ke-update
					GameState.emit_signal("npc_interacted")
					if dm and dm.has_method("show_rejection"):
						dm.show_rejection("%s menolak bicara: kamu terlalu Populis!" % name, self)
					else:
						print("%s menolak bicara, kamu terlalu Populis!" % name)
					return
				if meta.pref == "populis" and cur_bias <= -meta.bias_limit:
					GameState.taken_by_player[npc_key] = "ilfeel"
					GameState.emit_signal("npc_interacted")
					if dm and dm.has_method("show_rejection"):
						dm.show_rejection("%s menolak bicara: kamu terlalu Elitis!" % name, self)
					else:
						print("%s menolak bicara, kamu terlalu Elitis!" % name)
					return
		# --- END CEK BIAS ---

		if dm:
			dm.start_dialogue(self)
		else:
			print("[npc_story] ERROR: DialogueManager tidak ditemukan!")
