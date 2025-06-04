extends Camera2D

const MAP_WIDTH := 18 * 32 # 576 px
const MAP_HEIGHT := 18 * 32 # 576 px

func _process(delta):
	var viewport = get_viewport_rect().size
	var half_vw = (viewport.x * zoom.x) / 2
	var half_vh = (viewport.y * zoom.y) / 2

	var player_pos = get_parent().global_position

	# CLAMP kamera biar ga keluar map
	var cam_x = clamp(player_pos.x, half_vw, MAP_WIDTH - half_vw)
	var cam_y = clamp(player_pos.y, half_vh, MAP_HEIGHT - half_vh)

	global_position = Vector2(cam_x, cam_y)
