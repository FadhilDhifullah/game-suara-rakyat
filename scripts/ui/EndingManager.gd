extends Control

@onready var lbl_title = $LblTitle   as Label
@onready var txt_body  = $TxtBody    as RichTextLabel
@onready var btn_retry = $BtnRetry  as Button
@onready var btn_quit  = $BtnQuit   as Button

func _ready():
	_show_ending()
	btn_retry.pressed.connect(Callable(self, "_on_retry"))
	btn_quit.pressed.connect(Callable(self, "_on_quit"))

func _show_ending():
	# --- Prevent AI auto-win when player has not played ---
	if GameState.taken_by_player.size() == 0:
		lbl_title.text = "Belum Ada Interaksi!"
		txt_body.text  = "[center]Kamu belum bicara dengan NPC mana pun.\n\nMulai lagi dan coba strategi baru![/center]"
		return
	# -----------------------------------------------------
	var p_total = GameState.player_pop + GameState.player_elit + GameState.player_suap
	var a_total = GameState.ai_pop     + GameState.ai_elit     + GameState.ai_suap
	var p_sk    = GameState.player_risk >= GameState.RISK_THRESHOLD
	var a_sk    = GameState.ai_risk     >= GameState.RISK_THRESHOLD

	if p_sk and not a_sk:
		lbl_title.text = "Diskualifikasi Skandal!"
		txt_body.text  = "[center]Kamu tersangkut kasus korupsi. AI otomatis menang.[/center]"
	elif a_sk and not p_sk:
		lbl_title.text = "AI Diskualifikasi!"
		txt_body.text  = "[center]AI tersandung kasus korupsi—Kamu menang![/center]"
	elif p_sk and a_sk:
		lbl_title.text = "Pemilu Gagal!"
		txt_body.text  = "[center]Keduanya skandal. Pemilu harus diulang.[/center]"
	else:
		# Tentukan siapa pemenangnya dan warnanya
		if p_total > a_total:
			var color = ""
			if GameState.player_pop > GameState.player_elit:
				color = "Populis"
			else:
				color = "Elitis"
			lbl_title.text = "Kamu Menang sebagai Pemimpin %s!" % color
		else:
			var color = ""
			if GameState.ai_pop > GameState.ai_elit:
				color = "Populis"
			else:
				color = "Elitis"
			lbl_title.text = "AI Menang sebagai Pemimpin %s!" % color

		# Tampilkan skor dan risk
		txt_body.text = "[center]Suara kamu: %d vs AI: %d\nRisk kamu: %d/%d[/center]" % [
			p_total, a_total,
			GameState.player_risk, GameState.RISK_THRESHOLD
		]

func _on_retry():
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/scenes_1.tscn")

func _on_quit():
	get_tree().quit()
