extends Node

const scene_scene1 = preload("res://scenes/map/scenes_1_copy.tscn")
const scene_scene2 = preload("res://scenes/map/scenes_2_copy.tscn")

var spawn_door_tag

func go_to_level(level_tag, destination_tag):
	var scene_to_load

	match level_tag:
		"scene_1_copy":
			scene_to_load = scene_scene1
		"scene_2_copy":
			scene_to_load = scene_scene2

	if scene_to_load != null:
		print("Changing scene to:", scene_to_load)
		spawn_door_tag = destination_tag
		get_tree().change_scene_to_packed(scene_to_load)
