extends Node

signal score_updated
signal npc_interacted
signal last_action(text)

static func normalize_name(n: String) -> String:
	return n.strip_edges().to_lower().replace(" ", "_")

static func normalize_style(s: String) -> String:
	s = s.strip_edges().to_lower()
	if s in ["politik_uang", "politik uang", "suap"]:
		return "suap"
	if s in ["populis"]:
		return "populis"
	if s in ["elitis"]:
		return "elitis"
	return s

const NPC_META = {
	"pak_kholil": { "pref": "populis", "w": 1.0, "bribe": 0.8, "bias_limit": 1.0 },
	"pak_janggar": { "pref": "populis", "w": 1.0, "bribe": 0.7, "bias_limit": 1.0 },
	"pak_kemong":  { "pref": "populis", "w": 1.0, "bribe": 0.7, "bias_limit": 1.0 },
	"bu_ada":      { "pref": "populis", "w": 1.0, "bribe": 0.0, "bias_limit": 0.9 },
	"bu_tifa":     { "pref": "populis", "w": 1.2, "bribe": 0.5, "bias_limit": 0.95 },
	"elon_musk":   { "pref": "elitis",  "w": 2.0, "bribe": 0.6, "bias_limit": 0.7 },
	"pak_aries":   { "pref": "elitis",  "w": 1.0, "bribe": 0.0, "bias_limit": 0.8 },
	"mba_fayra":   { "pref": "elitis",  "w": 1.0, "bribe": 0.0, "bias_limit": 0.75 },
	"gus_fattah":  { "pref": "populis", "w": 1.5, "bribe": 0.6, "bias_limit": 0.95 },
	"mba_yorha":   { "pref": "elitis",  "w": 1.0, "bribe": 0.0, "bias_limit": 0.75 },
}

const RISK_THRESHOLD := 60.0
const LAMBDA_AI      := 0.6
const RISK_BUDGET    := 50.0

var player_pop := 0.0
var player_elit := 0.0
var player_suap := 0.0
var player_risk := 0.0
var taken_by_player := {}

var ai_pop := 0.0
var ai_elit := 0.0
var ai_suap := 0.0
var ai_risk := 0.0
var taken_by_ai := {}

func bias(pop: float, elit: float) -> float:
	if pop + elit == 0:
		return 0.0
	return (pop - elit) / (pop + elit)

func add_result_to_player(npc_name: String, style: String, bribe_success: bool = true):
	var key = normalize_name(npc_name)
	var meta = NPC_META.get(key, null)
	if meta == null:
		push_warning("NPC_META not found: %s" % key)
		return

	var style_std = normalize_style(style)
	var style_label = ""

	match style_std:
		"populis":
			if meta.pref == "populis":
				player_pop += 10 * meta.w
				style_label = "Populis +%.0f" % (10 * meta.w)
			else:
				player_pop += -5 * meta.w
				style_label = "Populis (tidak disukai) –%.0f" % (5 * meta.w)
		"elitis":
			if meta.pref == "elitis":
				player_elit += 10 * meta.w
				style_label = "Elitis +%.0f" % (10 * meta.w)
			else:
				player_elit += -5 * meta.w
				style_label = "Elitis (tidak disukai) –%.0f" % (5 * meta.w)
		"suap":
			if meta.bribe > 0:
				if bribe_success:
					player_suap += 20 * meta.w
					player_risk += 20 * meta.w
					style_label = "Suap +%.0f (Risk +%.0f)" % [20 * meta.w, 20 * meta.w]
				else:
					player_suap += -10 * meta.w
					player_risk += 10 * meta.w
					style_label = "Suap Gagal –%.0f (Risk +%.0f)" % [10 * meta.w, 10 * meta.w]
			else:
				player_suap += -10 * meta.w
				player_risk += 15 * meta.w
				style_label = "Suap (ditolak) –%.0f (Risk +%.0f)" % [10 * meta.w, 15 * meta.w]
		_:
			style_label = "Pilihan tidak diketahui"

	taken_by_player[key] = style_std
	emit_signal("score_updated")
	emit_signal("npc_interacted")
	emit_signal("last_action", style_label)

func run_ai_draft():
	for npc_name in NPC_META.keys():
		if taken_by_player.has(npc_name):
			var player_choice = taken_by_player[npc_name]
			var opsi_sisa = ["populis", "elitis", "suap"]
			opsi_sisa.erase(player_choice)
			_choose_for_ai(npc_name, opsi_sisa)

func _choose_for_ai(npc_name: String, opsi_sisa: Array):
	var meta = NPC_META[npc_name]
	var best_val = -INF
	var best_style = null
	var best_bribe_success = true
	for style in opsi_sisa:
		var style_std = normalize_style(style)
		var w = meta.w
		var val = 0.0
		var temp_gain = 0.0
		var temp_risk = 0.0

		match style_std:
			"populis":
				if meta.pref == "populis":
					temp_gain = 10 * w
				else:
					temp_gain = -5 * w
				temp_risk = 0
			"elitis":
				if meta.pref == "elitis":
					temp_gain = 10 * w
				else:
					temp_gain = -5 * w
				temp_risk = 0
			"suap":
				if meta.bribe > 0:
					var bribe_success = true  # AI asumsikan selalu sukses jika memilih suap (atau bisa random kalau mau)
					temp_gain = 20 * w
					temp_risk = 20 * w
				else:
					temp_gain = -10 * w
					temp_risk = 15 * w

		# AI tetap memperhitungkan bias limit dan risk budget
		var new_pop = ai_pop + (temp_gain if style_std == "populis" else 0)
		var new_elit = ai_elit + (temp_gain if style_std == "elitis" else 0)
		var new_risk = ai_risk + temp_risk
		if abs(bias(new_pop, new_elit)) > meta.bias_limit and style_std != "suap":
			continue  # ilfeel, skip opsi ini
		if new_risk > RISK_BUDGET and style_std == "suap":
			continue

		val = temp_gain - LAMBDA_AI * temp_risk
		if val > best_val:
			best_val = val
			best_style = style_std
			best_bribe_success = true  # AI suap selalu sukses (atau random, bisa diubah)

	if best_style == null:
		best_style = opsi_sisa[0]  # fallback, semestinya sangat jarang terjadi
	_apply_ai_choice(npc_name, best_style, best_bribe_success)

func _apply_ai_choice(npc_name: String, style: String, bribe_success: bool):
	var meta = NPC_META[npc_name]
	var w = meta.w
	var style_std = normalize_style(style)
	match style_std:
		"populis":
			if meta.pref == "populis":
				ai_pop += 10 * w
			else:
				ai_pop += -5 * w
		"elitis":
			if meta.pref == "elitis":
				ai_elit += 10 * w
			else:
				ai_elit += -5 * w
		"suap":
			if meta.bribe > 0:
				ai_suap += 20 * w
				ai_risk += 20 * w
			else:
				ai_suap += -10 * w
				ai_risk += 15 * w
	taken_by_ai[npc_name] = style_std

func reset():
	player_pop = 0.0
	player_elit = 0.0
	player_suap = 0.0
	player_risk = 0.0
	taken_by_player.clear()
	ai_pop = 0.0
	ai_elit = 0.0
	ai_suap = 0.0
	ai_risk = 0.0
	taken_by_ai.clear()
