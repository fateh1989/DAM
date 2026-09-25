extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _fail(code: int, message: String) -> void:
	push_error(message)
	quit(code)


func _run() -> void:
	var packed := load("res://source/world/MiddleEastTerrain.tscn")
	if packed == null:
		_fail(2, "Strategic unit smoke: scene load failed")
		return

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame

	if scene._units.size() != scene.GOVERNORATES.size() or scene._units.size() != 14:
		_fail(3, "Strategic unit smoke: expected one persistent tank per governorate")
		return

	var armies := {}
	for i in range(scene._units.size()):
		var unit: Dictionary = scene._units[i]
		armies[int(unit["army_id"])] = true
		if int(unit["governorate_index"]) != i:
			_fail(4, "Strategic unit smoke: governorate ownership mapping is inconsistent")
			return
	if armies.size() != 14:
		_fail(5, "Strategic unit smoke: each governorate must have a different army")
		return

	var radar = scene.get_node_or_null("HUD/RTSRadar")
	if radar == null:
		_fail(6, "Strategic unit smoke: RTS radar is missing")
		return

	var first_before: Dictionary = scene._units[0]
	var second_before: Dictionary = scene._units[1]
	var first_start := Vector2(float(first_before["lon"]), float(first_before["lat"]))
	var second_start := Vector2(float(second_before["lon"]), float(second_before["lat"]))

	var selected_indices: Array[int] = [0, 1]
	scene.select_units(selected_indices)
	if scene.get_selected_unit_count() != 2:
		_fail(12, "Strategic unit smoke: public multi-selection control failed")
		return
	scene.clear_selected_units()
	if scene.get_selected_unit_count() != 0:
		_fail(13, "Strategic unit smoke: clear selection control failed")
		return
	scene.select_all_units()
	if scene.get_selected_unit_count() != 14:
		_fail(14, "Strategic unit smoke: select all control failed")
		return
	scene.select_single_unit(1)
	if scene.get_selected_unit_count() != 1 or scene.get_selected_unit_indices()[0] != 1:
		_fail(17, "Strategic unit smoke: single selection control failed")
		return
	scene.toggle_unit_selection(0)
	if scene.get_selected_unit_count() != 2:
		_fail(18, "Strategic unit smoke: toggle selection add failed")
		return
	scene.toggle_unit_selection(0)
	if scene.get_selected_unit_count() != 1:
		_fail(19, "Strategic unit smoke: toggle selection remove failed")
		return
	scene.clear_selected_units()
	scene.select_next_unit()
	if scene.get_selected_unit_indices()[0] != 0:
		_fail(20, "Strategic unit smoke: select next did not start at first alive unit")
		return
	scene.select_next_unit()
	if scene.get_selected_unit_indices()[0] != 1:
		_fail(21, "Strategic unit smoke: select next did not advance")
		return
	scene.select_previous_unit()
	if scene.get_selected_unit_indices()[0] != 0:
		_fail(22, "Strategic unit smoke: select previous did not go back")
		return
	scene.select_units(selected_indices)
	if not scene.focus_selected_units():
		_fail(23, "Strategic unit smoke: focus selected control failed")
		return
	var focus_uv: Vector2 = scene.get_radar_camera_uv()
	if focus_uv.x < 0.0 or focus_uv.x > 1.0 or focus_uv.y < 0.0 or focus_uv.y > 1.0:
		_fail(24, "Strategic unit smoke: focus selected escaped map bounds")
		return
	scene.issue_selected_group_move(Vector2(first_start.x + 0.08, first_start.y))
	if scene.are_selected_units_stopped():
		_fail(15, "Strategic unit smoke: move command did not arm movement")
		return
	scene.stop_selected_units()
	if not scene.are_selected_units_stopped():
		_fail(16, "Strategic unit smoke: stop control failed")
		return
	scene.issue_selected_group_move(Vector2(first_start.x + 0.08, first_start.y))
	scene._process(1.0)

	var first_after: Dictionary = scene._units[0]
	var second_after: Dictionary = scene._units[1]
	var first_pos := Vector2(float(first_after["lon"]), float(first_after["lat"]))
	var second_pos := Vector2(float(second_after["lon"]), float(second_after["lat"]))
	if first_pos.distance_to(first_start) <= 0.000001:
		_fail(7, "Strategic unit smoke: first selected tank did not move")
		return
	if second_pos.distance_to(second_start) <= 0.000001:
		_fail(8, "Strategic unit smoke: second selected tank did not move")
		return

	var radar_units: Array = scene.get_radar_units()
	if radar_units.size() != 14:
		_fail(9, "Strategic unit smoke: radar does not mirror active armies")
		return

	var before_center: Vector2 = scene.get_radar_camera_uv()
	scene.radar_center_on_uv(Vector2(0.5, 0.5))
	var after_center: Vector2 = scene.get_radar_camera_uv()
	if after_center.distance_to(Vector2(0.5, 0.5)) > 0.001:
		_fail(10, "Strategic unit smoke: radar camera center failed")
		return
	if before_center.distance_to(after_center) < 0.000001:
		_fail(11, "Strategic unit smoke: radar camera did not move")
		return

	print("Strategic unit smoke: 14 armies + radar + group movement OK")
	quit(0)
