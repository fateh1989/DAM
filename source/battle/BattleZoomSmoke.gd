extends RefCounted

func run(world_scene: Node) -> String:
	var packed := load("res://source/battle/TacticalBattle.tscn")
	if packed == null:
		return "tactical battle scene could not be loaded for zoom guard"
	var battle = packed.instantiate()
	world_scene.add_child(battle)

	var original_ids: Array = battle.call("get_ground_chunk_instance_ids")
	var original_signature: Dictionary = battle.call("get_terrain_integrity_signature")
	if original_ids.size() != 25:
		battle.free()
		return "zoom guard expected the proven twenty five terrain chunks"

	battle.camera.position.x = 0.0
	battle.camera.position.z = battle.CAMERA_BACK_OFFSET_Z
	var target_before := Vector2(battle.camera.position.x, battle.camera.position.z - battle.CAMERA_BACK_OFFSET_Z)
	var previous_radar_area := INF

	for level in range(1, 7):
		battle.call("set_zoom_level", level, false)
		var expected_size := float(battle.call("get_zoom_target_size_for_level", level))
		if absf(battle.camera.size - expected_size) > 0.01:
			battle.free()
			return "zoom level %d did not apply its protected camera size" % level
		if not bool(battle.call("is_camera_ground_covered")):
			battle.free()
			return "zoom level %d exposes terrain outside visible chunks" % level
		if original_signature != battle.call("get_terrain_integrity_signature"):
			battle.free()
			return "zoom level %d mutated terrain integrity signature" % level
		if original_ids != battle.call("get_ground_chunk_instance_ids"):
			battle.free()
			return "zoom level %d rebuilt or replaced terrain chunks" % level
		var target_after := Vector2(battle.camera.position.x, battle.camera.position.z - battle.CAMERA_BACK_OFFSET_Z)
		if target_before.distance_to(target_after) > 0.01:
			battle.free()
			return "zoom level %d moved the camera target at battlefield center" % level
		var rect: Rect2 = battle.call("get_radar_camera_rect_uv")
		var radar_area := rect.size.x * rect.size.y
		if level > 1 and radar_area >= previous_radar_area:
			battle.free()
			return "radar viewport does not shrink monotonically toward close zoom"
		previous_radar_area = radar_area

	battle.call("set_zoom_level", 4, false)
	battle.free()
	return ""
