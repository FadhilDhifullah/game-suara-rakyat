extends Panel

@onready var lbl_title = $LblTitle   as Label
@onready var txt_body  = $TxtBody    as RichTextLabel
@onready var btn_retry = $BtnRetry   as Button
@onready var btn_quit  = $BtnQuit    as Button

func _ready():
	self.visible = false
	txt_body.bbcode_enabled = true
	btn_retry.pressed.connect(_on_retry)
	btn_quit.pressed.connect(_on_quit)

func show_ending():
	self.visible = true

	if GameState.taken_by_player.size() == 0:
		lbl_title.text = "Belum Ada Interaksi!"
		txt_body.text  = "[center]Kamu belum bicara dengan NPC mana pun.\n\nMulai lagi dan coba strategi baru![/center]"
		return

	var p_total = GameState.player_pop + GameState.player_elit + GameState.player_suap
	var a_total = GameState.ai_pop     + GameState.ai_elit     + GameState.ai_suap
	var p_sk    = GameState.player_risk >= GameState.RISK_THRESHOLD
	var a_sk    = GameState.ai_risk     >= GameState.RISK_THRESHOLD

	var detail = "[b]--- Perolehan Suara Player ---[/b]\n"
	detail += "- Populis      : [color=skyblue]%d[/color]\n" % int(GameState.player_pop)
	detail += "- Elitis       : [color=khaki]%d[/color]\n" % int(GameState.player_elit)
	detail += "- Politik Uang : [color=orange]%d[/color]\n" % int(GameState.player_suap)
	detail += "- Risk         : [color=crimson]%d[/color]/%d\n\n" % [int(GameState.player_risk), GameState.RISK_THRESHOLD]

	detail += "[b]--- Perolehan Suara AI ---[/b]\n"
	detail += "- Populis      : [color=skyblue]%d[/color]\n" % int(GameState.ai_pop)
	detail += "- Elitis       : [color=khaki]%d[/color]\n" % int(GameState.ai_elit)
	detail += "- Politik Uang : [color=orange]%d[/color]\n" % int(GameState.ai_suap)
	detail += "- Risk         : [color=crimson]%d[/color]/%d\n\n" % [int(GameState.ai_risk), GameState.RISK_THRESHOLD]

	detail += "[b]--- Total Suara ---[/b]\n"
	detail += "Kamu : [color=green]%d[/color]\n" % int(p_total)
	detail += "AI   : [color=green]%d[/color]\n\n" % int(a_total)

	detail += "[b]--- Pilihan Player Setiap NPC ---[/b]\n"
	for npc_name in GameState.NPC_META.keys():
		var disp_name = npc_name.capitalize().replace("_", " ")
		if GameState.taken_by_player.has(npc_name):
			var style = GameState.taken_by_player[npc_name]
			detail += "- %s : [color=lime]%s[/color]\n" % [disp_name, style.capitalize()]
		else:
			detail += "- %s : [color=gray]Belum dipilih[/color]\n" % disp_name

	detail += "\n[b]--- Pilihan AI Setiap NPC ---[/b]\n"
	for npc_name in GameState.NPC_META.keys():
		var disp_name = npc_name.capitalize().replace("_", " ")
		if GameState.taken_by_ai.has(npc_name):
			var style = GameState.taken_by_ai[npc_name]
			detail += "- %s : [color=gold]%s[/color]\n" % [disp_name, style.capitalize()]
		else:
			detail += "- %s : [color=gray]Belum dipilih[/color]\n" % disp_name

	detail += "\n"

	var alasan = ""
	if p_sk and not a_sk:
		lbl_title.text = "Diskualifikasi Skandal!"
		alasan = "[center]Kamu tersangkut kasus korupsi (Risk melewati batas). AI otomatis menang![/center]"
	elif a_sk and not p_sk:
		lbl_title.text = "AI Diskualifikasi!"
		alasan = "[center]AI tersandung kasus korupsi. Kamu menang otomatis![/center]"
	elif p_sk and a_sk:
		lbl_title.text = "Pemilu Gagal!"
		alasan = "[center]Kedua calon diskualifikasi karena skandal. Pemilu harus diulang![/center]"
	else:
		var color = ""
		if p_total > a_total:
			color = "Populis" if GameState.player_pop > GameState.player_elit else "Elitis"
			lbl_title.text = "Kamu Menang sebagai Pemimpin %s!" % color
			alasan = "[center]Selamat! Suara total kamu lebih tinggi dari AI.[/center]"
		elif a_total > p_total:
			color = "Populis" if GameState.ai_pop > GameState.ai_elit else "Elitis"
			lbl_title.text = "AI Menang sebagai Pemimpin %s!" % color
			alasan = "[center]Sayang sekali! Total suara AI lebih tinggi dari kamu.[/center]"
		else:
			lbl_title.text = "Seri!"
			alasan = "[center]Jumlah suara kamu dan AI persis sama. Tidak ada pemenang jelas.[/center]"

	txt_body.text = alasan + "\n\n[center][b]HASIL AKHIR[/b][/center]\n\n" + detail

func _on_retry():
	GameState.reset()
	self.visible = false

func _on_quit():
	get_tree().quit()
