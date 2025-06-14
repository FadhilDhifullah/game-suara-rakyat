extends Control  # atau CanvasLayer, sesuai node-mu

@onready var bar_citra    = $BarCitra
@onready var lbl_suara    = $LblSuara
@onready var bar_risk     = $BarRisk
@onready var lbl_npccount = $LblNPCcount
@onready var btn_finish   = $BtnFinish
@onready var lbl_action   = $LblLastAction
@onready var ending_panel = $EndingPanel  # <-- pastikan EndingPanel memang ada di bawah node ini!

func _ready():
	bar_citra.min_value = 0
	bar_citra.max_value = 100
	bar_risk.min_value = 0
	bar_risk.max_value = 100
	ending_panel.visible = false  # Pastikan tidak tampil sebelum waktunya
	
	btn_finish.pressed.connect(_on_finish_pressed)
	_update_all()
	
	if GameState.has_signal("score_updated"):
		GameState.connect("score_updated", Callable(self, "_update_all"))
	if GameState.has_signal("npc_interacted"):
		GameState.connect("npc_interacted", Callable(self, "_update_npccount"))
	if GameState.has_signal("last_action"):
		GameState.connect("last_action", Callable(self, "_update_last_action"))

func _update_all():
	_update_citra()
	lbl_suara.text = "%d" % int(GameState.player_pop + GameState.player_elit + GameState.player_suap)
	_update_risk()
	_update_npccount()
	_update_last_action()

func _update_citra():
	var b = GameState.bias(GameState.player_pop, GameState.player_elit)
	bar_citra.value = int(clamp((b + 1) * 50, 0, 100))

func _update_risk():
	bar_risk.value = clamp(float(GameState.player_risk) / float(GameState.RISK_THRESHOLD) * 100.0, 0.0, 100.0)

func _update_npccount():
	var done = GameState.taken_by_player.size()
	lbl_npccount.text = "%d / %d" % [done, GameState.NPC_META.size()]

func _update_last_action(text := ""):
	if text != "":
		lbl_action.text = str(text)

func _on_finish_pressed():
	GameState.run_ai_draft()
	ending_panel.show_ending()   # Panel ending baru tampil di sini saja!
