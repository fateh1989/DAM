extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _fail(code: int, message: String) -> void:
	push_error(message)
	quit(code)


func _run() -> void:
	var packed := load("res://source/world/MiddleEastTerrain.tscn")
	if packed == null:
		_fail(2, "Unit state smoke: scene load failed")
		return

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame

	if scene._units.size() != scene.GOVERNORATES.size() or scene._units.size() != 14:
		_fail(3, "Unit state smoke: expected one persistent tank per governorate")
		return

	var armies := {}
	for i in range(scene._units.size()):
		var unit: Dictionary = scene._units[i]
		armies[int(unit["army_id"])] = true
		if int(unit["governorate_index"]) != i:
			_fail(4, "Unit state smoke: governorate ownership mapping is inconsistent")
			return
	if armies.size() != 14:
		_fail(5, "Unit state smoke: each governorate must have a different army")
		return

	var radar = scene.get_node_or_null("HUD/RTSRadar")
	if radar == null:
		_fail(6, "Unit state smoke: RTS radar is missing")
		return

	scene._on_mode_pressed()
	await process_frame
	if not scene._terrain_mode:
		_fail(7, "Unit state smoke: terrain view did not activate")
		return
	if scene._map_zoom != scene.MAX_MAP_ZOOM:
		_fail(8, "Unit state smoke: tactical data zoom must stay fixed")
		return

	var scale_far: float = scene._tank_visual_scale()
	scene._on_zoom_in_pressed()
	await process_frame
	if scene._rts_zoom_level != 2:
		_fail(9, "Unit state smoke: second RTS camera zoom did not activate")
		return
	if scene._map_zoom != scene.MAX_MAP_ZOOM:
		_fail(10, "Unit state smoke: camera zoom changed world data zoom")
		return
	var scale_near: float = scene._tank_visual_scale()
	if not is_equal_approx(scale_far, scale_near):
		_fail(11, "Unit state smoke: camera zoom changed physical tank scale")
		return
	scene._on_zoom_out_pressed()
	if scene._rts_zoom_level != 1:
		_fail(12, "Unit state smoke: first RTS camera zoom did not restore")
		return

	var first_before: Dictionary = scene._units[0]
	var second_before: Dictionary = scene._units[1]
	var first_start := Vector2(float(first_before["lon"]), float(first_before["lat"]))
	var second_start := Vector2(float(second_before["lon"]), float(second_before["lat"]))

	scene._selected_unit_indices = [0, 1]
	scene._selected_unit_index = 1
	scene._issue_group_move_order(scene._selected_unit_indices, Vector2(first_start.x + 0.08, first_start.y))
	scene._process(1.0)

	var first_after: Dictionary = scene._units[0]
	var second_after: Dictionary = scene._units[1]
	var first_pos := Vector2(float(first_after["lon"]), float(first_after["lat"]))
	var second_pos := Vector2(float(second_after["lon"]), float(second_after["lat"]))
	if first_pos.distance_to(first_start) <= 0.000001:
		_fail(13, "Unit state smoke: first selected tank did not move")
		return
	if second_pos.distance_to(second_start) <= 0.000001:
		_fail(14, "Unit state smoke: second selected tank did not move")
		return

	var radar_units: Array = scene.get_radar_units()
	if radar_units.size() != 14:
		_fail(15, "Unit state smoke: radar does not mirror active armies")
		return

	var before_center: Vector2 = scene.get_radar_camera_uv()
	scene.radar_center_on_uv(Vector2(0.5, 0.5))
	var after_center: Vector2 = scene.get_radar_camera_uv()
	if after_center.distance_to(Vector2(0.5, 0.5)) > 0.001 or before_center.distance_to(after_center) < 0.000001:
		_fail(16, "Unit state smoke: radar camera jump failed")
		return

	scene._on_mode_pressed()
	await process_frame
	if scene._terrain_mode:
		_fail(17, "Unit state smoke: map view toggle failed")
		return

	scene._process(1.0)
	var after_map: Dictionary = scene._units[0]
	var map_pos := Vector2(float(after_map["lon"]), float(after_map["lat"]))
	if map_pos.distance_to(first_pos) <= 0.000001:
		_fail(18, "Unit state smoke: movement stopped when switching to map view")
		return

	print("Unit state smoke: 14 armies + 2-step RTS camera + radar + group movement OK")
	quit(0)
