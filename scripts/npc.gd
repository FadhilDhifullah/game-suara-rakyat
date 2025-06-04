# NPC.gd
# -----------------------------
# CharacterBody2D yang:
# - Setiap frame “re‐route” (BFS) ke last_goal, 
#   sehingga Player di jalan akan dihindari otomatis.
# - Jika tidak ada jalur (dead-end), gunakan ID-based priority untuk idle.
# - Snap ke tengah tile saat tiba → menghindari “floating” yang menyebabkan stuck.
# - Dirancang untuk “jalan 3 tile lebar = 96 px” sehingga NPC bisa menyalip via kolom lain.
# -----------------------------

extends CharacterBody2D

# ————————————————————————
# (1) PROPERTY UNTUK DI-EDIT DI INSPECTOR
# ————————————————————————

# NodePath ke node TileMapLayer yang berisi semua tile “road”
@export var npc_track_layer_path: NodePath

# Kecepatan NPC (pixel per detik)
@export var speed: float = 60.0

# Ukuran satu tile grid: 32×32 px
const TILE_SIZE: Vector2 = Vector2(32, 32)


# ————————————————————————
# (2) VARIABEL INTERNAL (JANGAN DI-EDIT)
# ————————————————————————

# Semua tile 'road' (Vector2i) di map
var road_tiles: Array[Vector2i] = []

# Adjacency list untuk BFS: tiap Vector2i → Array tetangganya (4‐arah)
var adjacency: Dictionary = {}

# Jalur Vector2i aktif (hasil BFS) dari tile sekarang ke last_goal
var current_path: Array[Vector2i] = []

# Indeks tile berikutnya di current_path
var path_index: int = 0

# Tile tujuan terakhir (last_goal)
var last_goal: Vector2i = Vector2i.ZERO

# Jika NPC tidak bisa jalan (dead-end), idle di sini
var idle_timer := 0.0

# Hitung berapa lama sudah idle → untuk mundur kalau >1 detik (opsional)
var stuck_timer := 0.0

# Tile sebelumnya (dipakai jika benar-benar deadlock → mundur 1 langkah)
var prev_tile: Vector2i = Vector2i.ZERO

# Dua tile terakhir ditempati (agar tidak ping-pong antara dua tile)
var recent_tiles: Array[Vector2i] = []

# Cache node
@onready var tilemap_layer: TileMapLayer = get_node_or_null(npc_track_layer_path) as TileMapLayer
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if tilemap_layer == null:
		push_error("⚠️ NPC.gd: TileMapLayer (road) tidak ditemukan! Periksa 'npc_track_layer_path'.")
		return

	# (A) Ambil semua tile “road” dan bangun adjacency (sekali di awal)
	_refresh_road_tiles()

	# (B) Pilih target random pertama (last_goal) & hitung BFS ke goal itu
	_pick_new_destination()

	# (C) Booking posisi awal (tile grid terdekat)
	var start_tile: Vector2i = _get_nearest_road_tile()
	NpcManager.occupy_tile(self.get_instance_id(), start_tile)
	prev_tile = start_tile

	# (D) Inisialisasi memory of last two tiles
	recent_tiles.clear()
	recent_tiles.push_back(start_tile)


func _physics_process(delta: float) -> void:
	# ——————————————————————————————
	# 1) Jika NPC sedang idle (blocked/dead-end)
	# ——————————————————————————————
	if idle_timer > 0.0:
		idle_timer -= delta
		stuck_timer += delta
		anim.stop()
		velocity = Vector2.ZERO
		move_and_slide()

		# Jika sudah idle > 1 detik, coba mundur ke prev_tile jika kosong
		if stuck_timer > 1.0 and prev_tile != Vector2i.ZERO and not NpcManager.is_tile_occupied(prev_tile, self.get_instance_id()):
			current_path = [prev_tile]
			path_index = 0
			stuck_timer = 0.0
			idle_timer = 0.0
		return
	else:
		stuck_timer = 0.0  # reset saat tidak idle

	# ——————————————————————————————
	# 2) Snap dan Booking jika tiba di tile yang dituju
	# ——————————————————————————————
	#    Kita akan selalu menghitung ulang "start_tile" → "current_path" secara dynamic.
	#    Bila sekarang sudah sampai di goal, pilih goal baru.
	var center_tile: Vector2i = _get_nearest_road_tile()
	if center_tile == last_goal:
		# Jika sudah mencapai last_goal, langsung pilih goal acak baru
		_pick_new_destination()
		return

	# ——————————————————————————————
	# 3) Hitung ulang rute (BFS) setiap frame:
	#    start_tile = tile di mana NPC sekarang berada
	#    → cari path baru ke last_goal, menghindari NPC lain & Player
	# ——————————————————————————————
	var path: Array[Vector2i] = _bfs_find_path(center_tile, last_goal)

	if path.is_empty():
		# Jika tidak ada rute sama sekali (dead-end), pakai ID-based priority untuk idle
		var blocked_tile: Vector2i = last_goal  # misalnya blocked oleh NPC/Player
		var other_id = NpcManager.get_npc_id_on_tile(blocked_tile, self.get_instance_id())
		if other_id != null and self.get_instance_id() > other_id:
			idle_timer = 0.6 + randf() * 0.2
		else:
			idle_timer = 0.1 + randf() * 0.1
		anim.stop()
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# Simpan path ke current_path dan reset path_index
	current_path = path.duplicate()
	path_index = 0

	# ——————————————————————————————
	# 4) Ambil tile berikutnya (path[1]) sebagai target pergerakan
	# ——————————————————————————————
	if current_path.size() < 2:
		# Berarti hanya ada satu tile (center_tile), artinya kita sudah di atas path → pilih goal baru
		_pick_new_destination()
		return

	var target_tile: Vector2i = current_path[1]

	# Hitung posisi center global dari target_tile
	var top_left: Vector2 = tilemap_layer.global_position + Vector2(
		target_tile.x * TILE_SIZE.x,
		target_tile.y * TILE_SIZE.y
	)
	var center_global: Vector2 = top_left + (TILE_SIZE * 0.5)

	# Vektor arah dari posisi NPC ke center_global
	var dir_vec: Vector2 = center_global - global_position

	# ——————————————————————————————
	# 5) Jika sudah dekat (≤ 2 px), snap, booking, dan update recent_tiles
	# ——————————————————————————————
	if dir_vec.length() <= 2.0:
		prev_tile = center_tile           # simpan tile sebelumnya
		global_position = center_global   # snap persis ke tengah tile
		NpcManager.occupy_tile(self.get_instance_id(), target_tile)

		# Update recent_tiles (maksimal 2)
		recent_tiles.push_back(target_tile)
		if recent_tiles.size() > 2:
			recent_tiles.pop_front()

		# Setelah snap, kita masih akan menunggu di node _physics_process selanjutnya
		return
	else:
		# ——————————————————————————————
		# 6) Jika belum sampai, langsung geser ke arah target_tile
		# ——————————————————————————————
		velocity = dir_vec.normalized() * speed
		move_and_slide()
		_update_animation(velocity)
	# end _physics_process()


# ——————————————————————————————
# (7) Helper: Cek apakah tile “blocked” oleh NPC lain atau Player
# ——————————————————————————————
func _is_tile_blocked(tile: Vector2i) -> bool:
	# Cek NPC lain
	if NpcManager.is_tile_occupied(tile, self.get_instance_id()):
		return true

	# Cek Player (diasumsikan Player ada di group "Player")
	for player_node in get_tree().get_nodes_in_group("Player"):
		var p_pos: Vector2
		if player_node.has_method("get_global_position"):
			p_pos = player_node.global_position
		else:
			p_pos = player_node.position
		var p_local: Vector2 = tilemap_layer.to_local(p_pos)
		var p_tile: Vector2i = tilemap_layer.local_to_map(p_local)
		if p_tile == tile:
			return true

	return false


# ——————————————————————————————
# (8) Helper: Cari tile “road” terdekat dari global_position
# ——————————————————————————————
func _get_nearest_road_tile() -> Vector2i:
	var local_pos: Vector2 = tilemap_layer.to_local(global_position)
	var maybe_tile: Vector2i = tilemap_layer.local_to_map(local_pos)
	if road_tiles.has(maybe_tile):
		return maybe_tile

	# Jika NPC tidak tepat di atas tile road, cari tile terdekat secara Euclidean
	var best_tile: Vector2i = road_tiles[0]
	var best_dist: float = 1e9
	for t in road_tiles:
		var top_left: Vector2 = tilemap_layer.global_position + Vector2(
			t.x * TILE_SIZE.x,
			t.y * TILE_SIZE.y
		)
		var center: Vector2 = top_left + (TILE_SIZE * 0.5)
		var d: float = global_position.distance_to(center)
		if d < best_dist:
			best_dist = d
			best_tile = t
	return best_tile


# ——————————————————————————————
# (9) Helper: BFS cari jalur terpendek dari 'start' ke 'goal',
#     skip tile yang sedang blocked (NPC/Player), kecuali goal itu sendiri
# ——————————————————————————————
func _bfs_find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not adjacency.has(start) or not adjacency.has(goal):
		return []
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = { start: null }
	var found: bool = false

	while queue.size() > 0:
		var u: Vector2i = queue.pop_front()
		if u == goal:
			found = true
			break
		for nb in adjacency[u]:
			# Abaikan jika nb blocked dan bukan goal
			if nb != goal and _is_tile_blocked(nb):
				continue
			if not visited.has(nb):
				visited[nb] = u
				queue.append(nb)
	if not found:
		return []

	# Trace-back dari goal ke start
	var rev_path: Array[Vector2i] = []
	var cur: Variant = goal
	while cur != null:
		rev_path.append(cur as Vector2i)
		cur = visited[cur]
	rev_path.reverse()
	return rev_path


# ——————————————————————————————
# (10) Helper: Baca semua tile “road” dari TileMapLayer (get_used_cells()),
#       lalu bangun adjacency list (4‐arah)
# ——————————————————————————————
func _refresh_road_tiles() -> void:
	road_tiles.clear()
	var used_cells: Array[Vector2i] = tilemap_layer.get_used_cells()
	for cell in used_cells:
		road_tiles.append(cell)

	adjacency.clear()
	for cell in road_tiles:
		var neighbors: Array[Vector2i] = []
		for dir in [
			Vector2i(1, 0),
			Vector2i(-1, 0),
			Vector2i(0, 1),
			Vector2i(0, -1)
		]:
			var nb: Vector2i = cell + dir
			if road_tiles.has(nb):
				neighbors.append(nb)
		adjacency[cell] = neighbors


# ——————————————————————————————
# (11) Helper: Pilih tujuan random (last_goal) dari road_tiles kecuali tile saat ini,
#       lalu hitung BFS ke goal tersebut. Jika BFS kosong, NPC akan idle.
# ——————————————————————————————
func _pick_new_destination() -> void:
	# A) Refresh daftar road_tiles (jika tilemap berubah runtime)
	_refresh_road_tiles()

	var start_tile: Vector2i = _get_nearest_road_tile()
	var possible_targets: Array[Vector2i] = []

	for t in road_tiles:
		if t != start_tile:
			# Jangan pilih dua langkah terakhir supaya tidak ping-pong terus
			if not recent_tiles.has(t):
				possible_targets.append(t)

	# Jika semua tile road hanya recent_tiles saja, pakai seluruh road_tiles (paksa)
	if possible_targets.is_empty():
		for t in road_tiles:
			if t != start_tile:
				possible_targets.append(t)

	if possible_targets.is_empty():
		current_path = []
		return

	var goal_tile: Vector2i = possible_targets[randi() % possible_targets.size()]
	last_goal = goal_tile

	# Hitung BFS dari start_tile ke goal_tile
	var path: Array[Vector2i] = _bfs_find_path(start_tile, goal_tile)
	if path.is_empty():
		# Jika tak ada rute, NPC akan idle beberapa saat, 
		# lalu di frame berikutnya _physics_process() akan memanggil re-route lagi
		current_path = []
		return

	current_path = path.duplicate()
	path_index = 0


# ——————————————————————————————
# (12) Helper: Update animasi sesuai arah velocity
# ——————————————————————————————
func _update_animation(vel: Vector2) -> void:
	if vel.length() < 1.0:
		anim.stop()
		return
	if abs(vel.x) > abs(vel.y):
		if vel.x > 0:
			anim.play("walk_right")
		else:
			anim.play("walk_left")
	else:
		if vel.y > 0:
			anim.play("walk_front")
		else:
			anim.play("walk_back")


# ——————————————————————————————
# (13) Ketika NPC dihapus, release booking tile di NpcManager
# ——————————————————————————————
func _exit_tree():
	NpcManager.release_tile(self.get_instance_id())
