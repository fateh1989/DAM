extends RefCounted

func run(_world_scene: Node) -> String:
	var packed := load("res://source/battle/TacticalBattle.tscn")
	if packed == null:
		return "tactical battle scene could not be loaded"
	var battle = packed.instantiate()
	_world_scene.add_child(battle)
	if absf(float(battle.call("get_battlefield_size")) - 10000.0) > 0.01:
		battle.free()
		return "battlefield did not expand to 10000 units"
	battle.camera.position = Vector3(9000.0, 850.0, 9000.0)
	battle.call("_clamp_camera_to_battlefield")
	var target_z := battle.camera.position.z - battle.CAMERA_BACK_OFFSET_Z
	if absf(battle.camera.position.x) > battle.BATTLEFIELD_HALF or absf(target_z) > battle.BATTLEFIELD_HALF:
		battle.free()
		return "camera escaped large battlefield bounds"
	if int(battle.call("get_ground_chunk_count")) != 25:
		battle.free()
		return "large battlefield was not divided into twenty five terrain chunks"
	var height_a := float(battle.call("terrain_height_at", -1400.0, -900.0))
	var height_b := float(battle.call("terrain_height_at", 1700.0, 1300.0))
	if absf(height_a - height_b) < 5.0:
		battle.free()
		return "battle terrain relief is effectively flat"
	for position in battle.call("get_friendly_positions"):
		var expected_y := float(battle.call("_unit_ground_y", position.x, position.z))
		if absf(position.y - expected_y) > 0.01:
			battle.free()
			return "friendly unit is not attached to terrain relief"
	battle.free()
	return ""
