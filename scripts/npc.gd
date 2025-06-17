extends CharacterBody2D

@export var npc_track_layer_path: NodePath
@export var speed: float = 60.0
const TILE_SIZE: Vector2 = Vector2(32, 32)

var road_tiles: Array[Vector2i] = []
var adjacency: Dictionary = {}
var current_path: Array[Vector2i] = []
var last_goal: Vector2i = Vector2i.ZERO
var prev_tile: Vector2i = Vector2i.ZERO
var recent_tiles: Array[Vector2i] = []
var idle_timer := 0.0
var stuck_timer := 0.0

var path_invalidated := true
var pathfinding_timer := 0.0
const PATHFINDING_INTERVAL := 0.2

@onready var tilemap_layer: TileMapLayer = get_node_or_null(npc_track_layer_path) as TileMapLayer
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if tilemap_layer == null:
		push_error("TileMapLayer tidak ditemukan!")
		return
	# Pastikan NPC ada di grup 'actors' untuk deteksi diri
	if not is_in_group("actors"):
		add_to_group("actors")
		
	_refresh_road_tiles()
	_pick_new_destination()
	var start_tile: Vector2i = _get_nearest_road_tile()
	prev_tile = start_tile
	recent_tiles.clear()
	recent_tiles.push_back(start_tile)

func _physics_process(delta: float) -> void:
	if idle_timer > 0.0:
		idle_timer -= delta
		stuck_timer += delta
		anim.stop()
		velocity = Vector2.ZERO
		move_and_slide()
		if stuck_timer > 1.0:
			# PERBAIKAN: Pilih destinasi baru saat benar-benar macet
			stuck_timer = 0.0
			idle_timer = 0.0
			_pick_new_destination()
		return
	else:
		stuck_timer = 0.0

	var center_tile: Vector2i = _get_nearest_road_tile()
	if center_tile == last_goal:
		_pick_new_destination()
		path_invalidated = true
		return

	pathfinding_timer -= delta
	if path_invalidated or pathfinding_timer <= 0.0 or current_path.is_empty():
		pathfinding_timer = PATHFINDING_INTERVAL
		var path = _bfs_find_path(center_tile, last_goal)
		if path.is_empty():
			idle_timer = 0.2 + randf() * 0.2
			anim.stop()
			velocity = Vector2.ZERO
			move_and_slide()
			return
		current_path = path.duplicate()
		path_invalidated = false

	if current_path.size() < 2:
		_pick_new_destination()
		path_invalidated = true
		return

	var target_tile: Vector2i = current_path[1]

	# Pengecekan ini sekarang jauh lebih kuat
	if _is_tile_blocked(target_tile) and target_tile != last_goal:
		path_invalidated = true
		return

	var top_left: Vector2 = tilemap_layer.global_position + Vector2(
		target_tile.x * TILE_SIZE.x,
		target_tile.y * TILE_SIZE.y
	)
	var center_global: Vector2 = top_left + (TILE_SIZE * 0.5)
	var dir_vec: Vector2 = center_global - global_position

	if dir_vec.length() <= 2.0:
		prev_tile = center_tile
		global_position = center_global
		recent_tiles.push_back(target_tile)
		if recent_tiles.size() > 2:
			recent_tiles.pop_front()
		# Setelah sampai di tile, pathnya berkurang 1, jadi kita hapus tile yg sudah dicapai
		current_path.pop_front() 
		return
	else:
		velocity = dir_vec.normalized() * speed
		move_and_slide()
		_update_animation(velocity)

# PERBAIKAN: Fungsi ini sekarang memeriksa semua 'actors'
func _is_tile_blocked(tile: Vector2i) -> bool:
	for actor in get_tree().get_nodes_in_group("actors"):
		if actor == self:
			continue
			
		if not is_instance_valid(actor) or not actor is Node2D:
			continue

		var actor_pos: Vector2 = actor.global_position
		var actor_local_pos: Vector2 = tilemap_layer.to_local(actor_pos)
		var actor_tile: Vector2i = tilemap_layer.local_to_map(actor_local_pos)
		
		if actor_tile == tile:
			return true
	return false

# ... sisa fungsi lainnya (get_nearest_road_tile, bfs_find_path, dll) tetap sama ...

func _get_nearest_road_tile() -> Vector2i:
	var local_pos: Vector2 = tilemap_layer.to_local(global_position)
	var maybe_tile: Vector2i = tilemap_layer.local_to_map(local_pos)
	if road_tiles.has(maybe_tile):
		return maybe_tile
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
		for nb in adjacency.get(u, []): # Gunakan .get() untuk keamanan
			# Pengecekan halangan di dalam BFS sangat penting
			if nb != goal and _is_tile_blocked(nb):
				continue
			if not visited.has(nb):
				visited[nb] = u
				queue.append(nb)
	if not found:
		return []
	var rev_path: Array[Vector2i] = []
	var cur: Variant = goal
	while cur != null:
		rev_path.append(cur as Vector2i)
		cur = visited[cur]
	rev_path.reverse()
	return rev_path

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

func _pick_new_destination() -> void:
	_refresh_road_tiles()
	var start_tile: Vector2i = _get_nearest_road_tile()
	var possible_targets: Array[Vector2i] = []
	for t in road_tiles:
		if t != start_tile and not recent_tiles.has(t):
			possible_targets.append(t)
	if possible_targets.is_empty():
		for t in road_tiles:
			if t != start_tile:
				possible_targets.append(t)
	if possible_targets.is_empty():
		current_path = []
		return
	var goal_tile: Vector2i = possible_targets[randi() % possible_targets.size()]
	last_goal = goal_tile
	# Pathfinding langsung dijalankan di sini agar lebih responsif
	path_invalidated = true
	pathfinding_timer = 0.0


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
