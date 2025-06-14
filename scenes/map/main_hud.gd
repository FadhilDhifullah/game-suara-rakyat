extends CanvasLayer

@onready var ending_panel = $EndingPanel  # Pastikan path ini benar!

func _on_btn_finish_pressed():
	# Fungsi ini dipasang ke tombol "Selesai Kampanye"
	print("==== [DEBUG] Tombol Selesai Kampanye Ditekan ====")
	print("Player sudah bicara ke:", GameState.taken_by_player.size())
	print("Isi taken_by_player:", GameState.taken_by_player)
	GameState.run_ai_draft()
	print("AI selesai draft, isi taken_by_ai:", GameState.taken_by_ai)
	ending_panel.show_ending() 
