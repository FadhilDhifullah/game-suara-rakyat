extends CanvasLayer

@export var player_texture: Texture  # Assign portrait player lewat inspector!

@onready var panel             = $DialogPanel
@onready var portrait_player   = $DialogPanel/PortraitPlayer
@onready var portrait_npc      = $DialogPanel/PortraitNPC
@onready var name_label        = $DialogPanel/NameLabel
@onready var dialog_text       = $DialogPanel/DialogText
@onready var button_next       = $DialogPanel/ButtonNext
@onready var button_cancel     = $DialogPanel/ButtonCancel
@onready var choices_container = $DialogPanel/ChoicesContainer

var current_npc : Node = null
var data        : Array = []
var index       : int = 0

func _ready() -> void:
	panel.visible = false
	button_next.visible = false
	button_cancel.visible = false
	choices_container.visible = false

	button_next.pressed.connect(_on_next_pressed)
	button_cancel.pressed.connect(_on_cancel_pressed)
	print("[DialogueManager] READY")
	portrait_player.texture = player_texture

func start_dialogue(npc_node: Node) -> void:
	print("[DialogueManager] start_dialogue dipanggil, npc:", npc_node)
	print("[DialogueManager] Data dialog:", npc_node.dialog_data)
	current_npc = npc_node
	data = npc_node.dialog_data.duplicate()
	index = 0
	portrait_npc.texture = npc_node.npc_texture
	portrait_player.texture = player_texture
	panel.visible = true
	button_cancel.visible = true
	_show_entry()

# Helper untuk cek nama speaker dan nama node NPC, tanpa peduli spasi/underscore/case
func is_npc_speaker(entry_speaker: String) -> bool:
	var npc_name_plain = current_npc.name.to_lower().replace("_", "").replace(" ", "")
	var speaker_plain = entry_speaker.to_lower().replace("_", "").replace(" ", "")
	return npc_name_plain == speaker_plain

func _show_entry() -> void:
	button_next.visible = false
	choices_container.visible = false
	dialog_text.text = ""
	for child in choices_container.get_children():
		child.queue_free()

	if index >= data.size():
		_end_dialogue()
		return

	var entry = data[index]
	print("DEBUG ENTRY INDEX:", index, "entry:", entry)
	name_label.text = entry.get("speaker", current_npc.name)
	var speaker = entry.get("speaker", "")

	# FOKUS dan Z-ORDERING portrait
	if speaker == "Player":
		portrait_player.modulate = Color(1,1,1,1)
		portrait_npc.modulate    = Color(0.5,0.5,0.5,1)
		portrait_player.z_index  = 1
		portrait_npc.z_index     = -1
	elif is_npc_speaker(speaker):
		portrait_player.modulate = Color(0.5,0.5,0.5,1)
		portrait_npc.modulate    = Color(1,1,1,1)
		portrait_player.z_index  = -1
		portrait_npc.z_index     = 1
	else:
		portrait_player.modulate = Color(0.7,0.7,0.7,1)
		portrait_npc.modulate    = Color(0.7,0.7,0.7,1)
		portrait_player.z_index  = -1
		portrait_npc.z_index     = -1

	if not entry.has("type"):
		push_error("Entry di index %d tidak punya key 'type'!\nentry: %s" % [index, str(entry)])
		_end_dialogue()
		return

	match entry["type"]:
		"text":
			dialog_text.text = entry["text"]
			button_next.visible = true
		"choice":
			dialog_text.text = entry["text"]
			_populate_choices(entry["choices"])
		"end":
			_end_dialogue()
		_:
			push_warning("Unknown dialog entry type: %s" % entry["type"])

	button_cancel.visible = true

func _on_next_pressed() -> void:
	var entry = data[index]
	if entry.has("next"):
		index = int(entry["next"])
		_show_entry()
	else:
		_end_dialogue()

func _on_cancel_pressed() -> void:
	print("[DialogueManager] Batal ditekan")
	_end_dialogue()

func _populate_choices(choices_array: Array) -> void:
	for i in range(choices_array.size()):
		var ch = choices_array[i]
		var btn = Button.new()
		btn.text = ch["label"]
		btn.name = str(i)
		btn.pressed.connect(func(): _on_choice_pressed(i))
		choices_container.add_child(btn)
	choices_container.visible = true

func _on_choice_pressed(choice_idx: int) -> void:
	var entry = data[index]
	var chosen = entry["choices"][choice_idx]
	if chosen.has("next"):
		index = int(chosen["next"])
		_show_entry()
	else:
		_end_dialogue()

func _end_dialogue() -> void:
	panel.visible = false
	button_next.visible = false
	button_cancel.visible = false
	choices_container.visible = false
	current_npc = null
	data.clear()
	index = 0

func _input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_cancel"):
		print("[DialogueManager] ui_cancel (ESC) ditekan")
		_end_dialogue()
