extends CanvasLayer

func _on_button_pressed():
	print("==== [DEBUG] Tombol Lihat Hasil Ditekan ====")
	print("Player sudah bicara ke:", GameState.taken_by_player.size())
	print("Isi taken_by_player:", GameState.taken_by_player)
	GameState.run_ai_draft()
	print("AI selesai draft, isi taken_by_ai:", GameState.taken_by_ai)
	EndingManager.show_result()


func _on_button_finish_pressed() -> void:
	pass # Replace with function body.
