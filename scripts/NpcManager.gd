# NpcManager.gd
# -----------------------------
# Singleton (autoload) untuk mencatat tile mana yang 'dikuasai' tiap NPC.
# Juga helper: mendapatkan ID NPC yang menempati tile tertentu.
# -----------------------------

extends Node

# key = instance_id NPC,  value = Vector2i (tile yang sedang ditempati)
var occupied_tiles := {}

func occupy_tile(npc_id, tile: Vector2i) -> void:
	occupied_tiles[npc_id] = tile

func release_tile(npc_id) -> void:
	occupied_tiles.erase(npc_id)

func is_tile_occupied(tile: Vector2i, exclude_npc_id = null) -> bool:
	for id_key in occupied_tiles.keys():
		if occupied_tiles[id_key] == tile and id_key != exclude_npc_id:
			return true
	return false

func get_npc_id_on_tile(tile: Vector2i, exclude_npc_id = null):
	for id_key in occupied_tiles.keys():
		if occupied_tiles[id_key] == tile and id_key != exclude_npc_id:
			return id_key
	return null
