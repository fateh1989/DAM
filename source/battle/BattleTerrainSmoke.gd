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
	var target_z: float = battle.camera.position.z - battle.CAMERA_BACK_OFFSET_Z
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
	var shader_text := FileAccess.get_file_as_string("res://source/battle/shaders/BattleGround.gdshader")
	if "rock_mask" not in shader_text or "scrub_green" not in shader_text:
		battle.free()
		return "battle ground shader is missing natural terrain blending"
	if "continental" not in shader_text:
		battle.free()
		return "battle ground shader lacks broad macro variation"
	var valley_near := float(battle.call("terrain_valley_mask_at", 220.0, 0.0))
	var valley_far := float(battle.call("terrain_valley_mask_at", 2200.0, 0.0))
	if valley_near < 0.8 or valley_far > 0.2:
		battle.free()
		return "terrain valley mask is not carving a localized corridor"
	var local_a := float(battle.call("terrain_height_at", 1200.0, 900.0))
	var local_b := float(battle.call("terrain_height_at", 1325.0, 900.0))
	if absf(local_a - local_b) < 0.5:
		battle.free()
		return "terrain surface lacks local erosion relief"
	if int(battle.call("get_terrain_prop_count")) < 40:
		battle.free()
		return "terrain lacks procedural rock and scrub detail"
	var initial_visible := int(battle.call("get_visible_ground_chunk_count"))
	if initial_visible <= 0 or initial_visible >= int(battle.call("get_ground_chunk_count")):
		battle.free()
		return "terrain chunk culling is not limiting rendered ground"
	battle.camera.size = 4200.0
	battle.call("_clamp_camera_to_battlefield")
	battle.call("_sync_terrain_chunk_visibility")
	if not bool(battle.call("is_camera_ground_covered")):
		battle.free()
		return "terrain culling leaves holes when camera zooms outward"
	battle.camera.size = battle.ZOOM_NORMAL
	battle.call("_sync_terrain_chunk_visibility")
	var terrain_signature_before: Dictionary = battle.call("get_terrain_integrity_signature")
	battle.camera.size = 5200.0
	battle.call("_sync_terrain_chunk_visibility")
	var terrain_signature_after: Dictionary = battle.call("get_terrain_integrity_signature")
	if terrain_signature_before != terrain_signature_after:
		battle.free()
		return "camera zoom mutated terrain geometry or world scale"
	battle.camera.size = battle.ZOOM_NORMAL
	battle.call("_sync_terrain_chunk_visibility")
	battle.call("radar_center_on_uv", Vector2(0.94, 0.94))
	var edge_visible := int(battle.call("get_visible_ground_chunk_count"))
	if edge_visible <= 0 or edge_visible >= int(battle.call("get_ground_chunk_count")):
		battle.free()
		return "terrain culling failed after moving to battlefield edge"
	if not (battle.call("get_battle_ground_material") is ShaderMaterial):
		battle.free()
		return "battle terrain is not using the natural ground shader"
	battle.free()
	return ""
