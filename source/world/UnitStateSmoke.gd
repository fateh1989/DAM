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

	scene._on_mode_pressed()
	await process_frame
	if not scene._terrain_mode:
		_fail(6, "Unit state smoke: terrain view did not activate")
		return

	scene._on_zoom_wheel_changed(6.0)
	await process_frame
	if not scene._terrain_mode:
		_fail(7, "Unit state smoke: zooming out incorrectly switched away from RTS terrain")
		return
	if not scene._is_tactical_overview():
		_fail(8, "Unit state smoke: Syria-wide RTS overview did not activate")
		return

	var before: Dictionary = scene._units[0]
	var start := Vector2(float(before["lon"]), float(before["lat"]))
	scene._issue_move_order(0, Vector2(start.x + 0.08, start.y))
	scene._process(1.0)
	var after_terrain: Dictionary = scene._units[0]
	var terrain_pos := Vector2(float(after_terrain["lon"]), float(after_terrain["lat"]))
	if terrain_pos.distance_to(start) <= 0.000001:
		_fail(9, "Unit state smoke: tank did not move after a player move order")
		return

	scene._on_mode_pressed()
	await process_frame
	if scene._terrain_mode:
		_fail(10, "Unit state smoke: map view toggle failed")
		return

	scene._process(1.0)
	var after_map: Dictionary = scene._units[0]
	var map_pos := Vector2(float(after_map["lon"]), float(after_map["lat"]))
	if map_pos.distance_to(terrain_pos) <= 0.000001:
		_fail(11, "Unit state smoke: movement stopped when switching to map view")
		return

	var expected_target := Vector2(float(after_map["target_lon"]), float(after_map["target_lat"]))
	scene._on_mode_pressed()
	await process_frame
	var after_return: Dictionary = scene._units[0]
	var return_pos := Vector2(float(after_return["lon"]), float(after_return["lat"]))
	var return_target := Vector2(float(after_return["target_lon"]), float(after_return["target_lat"]))
	if int(after_return["army_id"]) != 1 or return_target.distance_to(expected_target) > 0.000001:
		_fail(12, "Unit state smoke: unit identity or move order changed while switching views")
		return
	if return_pos.distance_to(start) + 0.000001 < map_pos.distance_to(start):
		_fail(13, "Unit state smoke: tank moved backwards or reset while switching views")
		return

	print("Unit state smoke: 14 armies + persistent RTS/map movement OK")
	quit(0)
