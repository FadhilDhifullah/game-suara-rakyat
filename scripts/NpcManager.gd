extends Node

var occupied_tiles: Dictionary = {}
var booked_tiles: Dictionary = {}

func occupy_tile(npc_id, tile: Vector2i) -> void:
	occupied_tiles[tile] = npc_id

func release_tile(npc_id) -> void:
	var keys = []
	for tile in occupied_tiles:
		if occupied_tiles[tile] == npc_id:
			keys.append(tile)
	for tile in keys:
		occupied_tiles.erase(tile)

func is_tile_occupied(tile: Vector2i, self_id) -> bool:
	return occupied_tiles.has(tile) and occupied_tiles[tile] != self_id

func get_npc_id_on_tile(tile: Vector2i, self_id) -> Variant:
	if occupied_tiles.has(tile) and occupied_tiles[tile] != self_id:
		return occupied_tiles[tile]
	return null


func book_tile(npc_id, tile: Vector2i) -> bool:
	if booked_tiles.has(tile) and booked_tiles[tile] != npc_id:
		return false
	booked_tiles[tile] = npc_id
	return true

func release_tile_booking(npc_id, tile: Vector2i) -> void:
	if booked_tiles.has(tile) and booked_tiles[tile] == npc_id:
		booked_tiles.erase(tile)
