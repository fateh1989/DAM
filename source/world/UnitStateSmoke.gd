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

	var continuous_world_id: int = int(scene.get_instance_id())
	if not bool(scene.get("_terrain_mode")):
		_fail(70, "Continuous RTS smoke: world did not boot directly into RTS terrain")
		return
	await process_frame
	if not is_instance_valid(scene) or scene.get_instance_id() != continuous_world_id or scene.get_parent() != root:
		_fail(71, "Continuous RTS smoke: world scene was replaced during boot")
		return

	var selection_contract_script := load("res://source/world/SelectionCoreSmoke.gd") as Script
	if selection_contract_script == null:
		_fail(52, "Selection core smoke: contract script missing")
		return
	var selection_contract = selection_contract_script.new()
	var selection_error := str(selection_contract.call("run", scene))
	if not selection_error.is_empty():
		_fail(53, "Selection core smoke: " + selection_error)
		return

	var radar_contract_script := load("res://source/world/RadarCoreSmoke.gd") as Script
	if radar_contract_script == null:
		_fail(54, "Radar core smoke: contract script missing")
		return
	var radar_contract = radar_contract_script.new()
	var radar_error := str(radar_contract.call("run", scene))
	if not radar_error.is_empty():
		_fail(55, "Radar core smoke: " + radar_error)
		return

	var movement_contract_script := load("res://source/world/MovementCoreSmoke.gd") as Script
	if movement_contract_script == null:
		_fail(56, "Movement core smoke: contract script missing")
		return
	var movement_contract = movement_contract_script.new()
	var movement_error := str(movement_contract.call("run", scene))
	if not movement_error.is_empty():
		_fail(57, "Movement core smoke: " + movement_error)
		return

	var mobile_contract_script := load("res://source/world/MobileControlSmoke.gd") as Script
	if mobile_contract_script == null:
		_fail(58, "Mobile control smoke: contract script missing")
		return
	var mobile_contract = mobile_contract_script.new()
	var mobile_error := str(mobile_contract.call("run", scene))
	if not mobile_error.is_empty():
		_fail(59, "Mobile control smoke: " + mobile_error)
		return

	var province_clock_smoke_script := load("res://source/world/ProvinceClockSmoke.gd") as Script
	if province_clock_smoke_script == null:
		_fail(60, "Province clock smoke: contract script missing")
		return
	var province_clock_smoke = province_clock_smoke_script.new()
	var province_clock_error := str(province_clock_smoke.call("run", scene))
	if not province_clock_error.is_empty():
		_fail(61, "Province clock smoke: " + province_clock_error)
		return

	var terrain_zoom_smoke_script := load("res://source/world/TerrainZoomSmoke.gd") as Script
	if terrain_zoom_smoke_script == null:
		_fail(62, "Terrain zoom smoke: contract script missing")
		return
	var terrain_zoom_smoke = terrain_zoom_smoke_script.new()
	var terrain_zoom_error := str(terrain_zoom_smoke.call("run", scene))
	if not terrain_zoom_error.is_empty():
		_fail(63, "Terrain zoom smoke: " + terrain_zoom_error)
		return

	var landmark_smoke_script := load("res://source/world/ProvinceLandmarkSmoke.gd") as Script
	if landmark_smoke_script == null:
		_fail(64, "Province landmark smoke: contract script missing")
		return
	var landmark_smoke = landmark_smoke_script.new()
	var landmark_error := str(landmark_smoke.call("run", scene))
	if not landmark_error.is_empty():
		_fail(65, "Province landmark smoke: " + landmark_error)
		return


	if scene._units.size() != scene.GOVERNORATES.size() * 3 or scene._units.size() != 42:
		_fail(3, "Strategic unit smoke: expected tank artillery and launcher representatives in every governorate")
		return

	var armies := {}
	var type_counts := {"tank": 0, "artillery": 0, "rocket_launcher": 0}
	for unit in scene._units:
		var item: Dictionary = unit
		var governorate_index := int(item["governorate_index"])
		if governorate_index < 0 or governorate_index >= scene.GOVERNORATES.size():
			_fail(4, "Strategic unit smoke: governorate ownership mapping is outside bounds")
			return
		if int(item["army_id"]) != governorate_index + 1:
			_fail(4, "Strategic unit smoke: army id no longer matches governorate ownership")
			return
		armies[int(item["army_id"])] = true
		var unit_type := str(item.get("unit_type", ""))
		if not type_counts.has(unit_type):
			_fail(78, "Strategic unit smoke: unexpected heavy representative type")
			return
		type_counts[unit_type] = int(type_counts[unit_type]) + 1
	if armies.size() != 14:
		_fail(5, "Strategic unit smoke: each governorate must have a different army")
		return
	for required_type in type_counts.keys():
		if int(type_counts[required_type]) != scene.GOVERNORATES.size():
			_fail(79, "Strategic unit smoke: heavy representative count mismatch for " + str(required_type))
			return

	var tank_visual_error := str(scene.call("validate_strategic_tank_visuals"))
	if not tank_visual_error.is_empty():
		_fail(77, "Strategic tank visual smoke: " + tank_visual_error)
		return
	var support_visual_error := str(scene.call("validate_support_heavy_visuals"))
	if not support_visual_error.is_empty():
		_fail(80, "Support heavy visual smoke: " + support_visual_error)
		return

	var heavy_roster_smoke_script := load("res://source/world/HeavyRosterSmoke.gd") as Script
	if heavy_roster_smoke_script == null:
		_fail(81, "Heavy roster smoke: contract script missing")
		return
	var heavy_roster_smoke = heavy_roster_smoke_script.new()
	var heavy_roster_error := str(heavy_roster_smoke.call("run", scene))
	if not heavy_roster_error.is_empty():
		_fail(82, "Heavy roster smoke: " + heavy_roster_error)
		return

	var heavy_movement_smoke_script := load("res://source/world/HeavyMovementPersistenceSmoke.gd") as Script
	if heavy_movement_smoke_script == null:
		_fail(83, "Heavy movement persistence smoke: contract script missing")
		return
	var heavy_movement_smoke = heavy_movement_smoke_script.new()
	var heavy_movement_error := str(heavy_movement_smoke.call("run", scene))
	if not heavy_movement_error.is_empty():
		_fail(84, "Heavy movement persistence smoke: " + heavy_movement_error)
		return

	var partial_damage_smoke_script := load("res://source/world/PartialDamagePersistenceSmoke.gd") as Script
	if partial_damage_smoke_script == null:
		_fail(85, "Partial damage persistence smoke: contract script missing")
		return
	var partial_damage_smoke = partial_damage_smoke_script.new()
	var partial_damage_error := str(partial_damage_smoke.call("run", scene))
	if not partial_damage_error.is_empty():
		_fail(86, "Partial damage persistence smoke: " + partial_damage_error)
		return

	var logical_heavy_movement_smoke_script := load("res://source/world/LogicalHeavyMovementSmoke.gd") as Script
	if logical_heavy_movement_smoke_script == null:
		_fail(87, "Logical heavy movement smoke: contract script missing")
		return
	var logical_heavy_movement_smoke = logical_heavy_movement_smoke_script.new()
	var logical_heavy_movement_error := str(logical_heavy_movement_smoke.call("run", scene))
	if not logical_heavy_movement_error.is_empty():
		_fail(88, "Logical heavy movement smoke: " + logical_heavy_movement_error)
		return

	var radar = scene.get_node_or_null("HUD/RTSRadar")
	if radar == null:
		_fail(6, "Strategic unit smoke: RTS radar is missing")
		return

	if scene.get_radar_action_mode() != "camera":
		_fail(37, "Strategic unit smoke: radar action mode must start in camera mode")
		return
	scene.toggle_radar_action_mode()
	if scene.get_radar_action_mode() != "move":
		_fail(38, "Strategic unit smoke: radar action mode did not toggle to move")
		return
	scene.set_radar_action_mode("camera")
	if scene.get_radar_action_mode() != "camera":
		_fail(39, "Strategic unit smoke: radar action mode did not restore camera")
		return

	var radar_mode_button := scene.get_node_or_null("HUD/CommandBar/Row/RadarModeButton") as Button
	if radar_mode_button == null:
		_fail(40, "Strategic unit smoke: radar mode command button missing")
		return
	radar_mode_button.emit_signal("pressed")
	if scene.get_radar_action_mode() != "move" or radar_mode_button.text != "RADAR MOVE":
		_fail(41, "Strategic unit smoke: radar move button cycle failed")
		return
	radar_mode_button.emit_signal("pressed")
	if scene.get_radar_action_mode() != "select" or radar_mode_button.text != "RADAR SELECT":
		_fail(43, "Strategic unit smoke: radar select button cycle failed")
		return
	radar_mode_button.emit_signal("pressed")
	if scene.get_radar_action_mode() != "camera" or radar_mode_button.text != "RADAR CAMERA":
		_fail(44, "Strategic unit smoke: radar camera button cycle failed")
		return

	scene.set_radar_action_mode("select")
	if scene.get_radar_action_mode() != "select":
		_fail(49, "Strategic unit smoke: radar select mode was rejected")
		return
	scene.cycle_radar_action_mode()
	if scene.get_radar_action_mode() != "camera":
		_fail(50, "Strategic unit smoke: radar mode cycle did not wrap to camera")
		return

	var first_radar_item: Dictionary = scene.get_radar_units()[0]
	scene.clear_selected_units()
	var nearest_index: int = scene.select_nearest_unit_uv(first_radar_item.get("uv", Vector2.ZERO))
	if nearest_index != 0 or scene.get_selected_unit_count() != 1:
		_fail(48, "Strategic unit smoke: radar nearest-unit selection failed")
		return
	scene.clear_selected_units()

	scene.set_radar_action_mode("select")
	radar.call("apply_action_uv", first_radar_item.get("uv", Vector2.ZERO))
	if scene.get_selected_unit_count() != 1 or scene.get_selected_unit_indices()[0] != 0:
		_fail(51, "Strategic unit smoke: radar select mode did not select tapped unit")
		return
	scene.clear_selected_units()
	scene.set_radar_action_mode("camera")

	var select_all_button := scene.get_node_or_null("HUD/CommandBar/Row/SelectAllUnitsButton") as Button
	if select_all_button == null:
		_fail(26, "Strategic unit smoke: select all command button missing")
		return
	select_all_button.emit_signal("pressed")
	if scene.get_selected_unit_count() != 42:
		_fail(27, "Strategic unit smoke: select all command button failed")
		return
	if "SELECTED 42" not in scene.status_label.text:
		_fail(45, "Strategic unit smoke: selected unit count missing from status HUD")
		return
	var clear_button := scene.get_node_or_null("HUD/CommandBar/Row/ClearSelectionButton") as Button
	if clear_button == null:
		_fail(28, "Strategic unit smoke: clear command button missing")
		return
	clear_button.emit_signal("pressed")
	if scene.get_selected_unit_count() != 0:
		_fail(29, "Strategic unit smoke: clear command button failed")
		return
	if "SELECTED" in scene.status_label.text:
		_fail(46, "Strategic unit smoke: cleared selection remained in status HUD")
		return

	var previous_button := scene.get_node_or_null("HUD/CommandBar/Row/PreviousUnitButton") as Button
	var next_button := scene.get_node_or_null("HUD/CommandBar/Row/NextUnitButton") as Button
	if previous_button == null or next_button == null:
		_fail(30, "Strategic unit smoke: previous/next unit command buttons missing")
		return
	next_button.emit_signal("pressed")
	if scene.get_selected_unit_indices()[0] != 0:
		_fail(31, "Strategic unit smoke: next unit command button did not select first unit")
		return
	next_button.emit_signal("pressed")
	if scene.get_selected_unit_indices()[0] != 1:
		_fail(32, "Strategic unit smoke: next unit command button did not advance")
		return
	previous_button.emit_signal("pressed")
	if scene.get_selected_unit_indices()[0] != 0:
		_fail(33, "Strategic unit smoke: previous unit command button did not go back")
		return
	scene.clear_selected_units()
	var focus_button := scene.get_node_or_null("HUD/CommandBar/Row/FocusUnitsButton") as Button
	var stop_button := scene.get_node_or_null("HUD/CommandBar/Row/StopUnitsButton") as Button
	if stop_button == null:
		_fail(36, "Strategic unit smoke: stop command button missing")
		return
	if focus_button == null:
		_fail(34, "Strategic unit smoke: focus command button missing")
		return
	scene.select_single_unit(0)
	focus_button.emit_signal("pressed")
	var focused_uv: Vector2 = scene.get_radar_camera_uv()
	if focused_uv.x < 0.0 or focused_uv.x > 1.0 or focused_uv.y < 0.0 or focused_uv.y > 1.0:
		_fail(35, "Strategic unit smoke: focus command button moved outside map")
		return
	scene.clear_selected_units()

	var first_before: Dictionary = scene._units[0]
	var second_before: Dictionary = scene._units[1]
	var first_start := Vector2(float(first_before["lon"]), float(first_before["lat"]))
	var second_start := Vector2(float(second_before["lon"]), float(second_before["lat"]))

	var selected_indices: Array[int] = [0, 1]
	scene.select_units(selected_indices)
	if scene.get_selected_unit_count() != 2:
		_fail(12, "Strategic unit smoke: public multi-selection control failed")
		return
	scene.stop_selected_units()
	scene._handle_world_tap(Vector2(1.0, 1.0))
	if scene.are_selected_units_stopped():
		_fail(74, "Continuous RTS smoke: ground tap did not move selected units")
		return
	scene.stop_selected_units()
	scene.set_radar_action_mode("move")
	radar.call("apply_action_uv", Vector2(0.75, 0.75))
	if scene.are_selected_units_stopped():
		_fail(42, "Strategic unit smoke: radar move mode did not issue group movement")
		return
	scene.stop_selected_units()
	scene.set_radar_action_mode("camera")
	scene.clear_selected_units()
	if scene.get_selected_unit_count() != 0:
		_fail(13, "Strategic unit smoke: clear selection control failed")
		return
	scene.select_all_units()
	if scene.get_selected_unit_count() != 42:
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
	scene.issue_selected_group_move_uv(Vector2(0.80, 0.80))
	if scene.are_selected_units_stopped():
		_fail(25, "Strategic unit smoke: radar move control did not arm movement")
		return
	scene.stop_selected_units()
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
	stop_button.emit_signal("pressed")
	if not scene.are_selected_units_stopped():
		_fail(16, "Strategic unit smoke: stop command button failed")
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
	if radar_units.size() != 42:
		_fail(9, "Strategic unit smoke: radar does not mirror active heavy representatives")
		return

	if int((radar_units[0] as Dictionary).get("index", -1)) != 0:
		_fail(47, "Strategic unit smoke: radar blip lost source unit index")
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

	var game_visual_aim_smoke_script := load("res://source/world/GameVisualAimSmoke.gd") as Script
	if game_visual_aim_smoke_script == null:
		_fail(97, "Game visual aim smoke: contract script missing")
		return
	var game_visual_aim_smoke = game_visual_aim_smoke_script.new()
	var game_visual_aim_error := str(game_visual_aim_smoke.call("run", scene))
	if not game_visual_aim_error.is_empty():
		_fail(98, "Game visual aim smoke: " + game_visual_aim_error)
		return

	var visible_combat_smoke_script := load("res://source/world/VisibleCombatPersistenceSmoke.gd") as Script
	if visible_combat_smoke_script == null:
		_fail(85, "Visible combat persistence smoke: contract script missing")
		return
	var visible_combat_smoke = visible_combat_smoke_script.new()
	var visible_combat_error := str(visible_combat_smoke.call("run", scene))
	if not visible_combat_error.is_empty():
		_fail(86, "Visible combat persistence smoke: " + visible_combat_error)
		return

	var continuity_smoke_script := load("res://source/world/WorldContinuitySmoke.gd") as Script
	if continuity_smoke_script == null:
		_fail(75, "World continuity smoke: contract script missing")
		return
	var continuity_smoke = continuity_smoke_script.new()
	var continuity_error := str(continuity_smoke.call("run", scene))
	if not continuity_error.is_empty():
		_fail(76, "World continuity smoke: " + continuity_error)
		return

	var logical_selection_smoke_script := load("res://source/world/LogicalHeavySelectionSmoke.gd") as Script
	if logical_selection_smoke_script == null:
		_fail(89, "Logical heavy selection smoke: contract script missing")
		return
	var logical_selection_smoke = logical_selection_smoke_script.new()
	var logical_selection_error := str(logical_selection_smoke.call("run", scene))
	if not logical_selection_error.is_empty():
		_fail(90, "Logical heavy selection smoke: " + logical_selection_error)
		return

	var logical_force_group_smoke_script := load("res://source/world/LogicalForceGroupSmoke.gd") as Script
	if logical_force_group_smoke_script == null:
		_fail(91, "Logical force group smoke: contract script missing")
		return
	var logical_force_group_smoke = logical_force_group_smoke_script.new()
	var logical_force_group_error := str(logical_force_group_smoke.call("run", scene))
	if not logical_force_group_error.is_empty():
		_fail(92, "Logical force group smoke: " + logical_force_group_error)
		return

	var touch_logical_selection_smoke_script := load("res://source/world/TouchLogicalSelectionSmoke.gd") as Script
	if touch_logical_selection_smoke_script == null:
		_fail(93, "Touch logical selection smoke: contract script missing")
		return
	var touch_logical_selection_smoke = touch_logical_selection_smoke_script.new()
	var touch_logical_selection_error := str(touch_logical_selection_smoke.call("run", scene))
	if not touch_logical_selection_error.is_empty():
		_fail(94, "Touch logical selection smoke: " + touch_logical_selection_error)
		return

	var rectangle_selection_smoke_script := load("res://source/world/RectangleLogicalSelectionSmoke.gd") as Script
	if rectangle_selection_smoke_script == null:
		_fail(95, "Rectangle logical selection smoke: contract script missing")
		return
	var rectangle_selection_smoke = rectangle_selection_smoke_script.new()
	var rectangle_selection_error := str(rectangle_selection_smoke.call("run", scene))
	if not rectangle_selection_error.is_empty():
		_fail(96, "Rectangle logical selection smoke: " + rectangle_selection_error)
		return

	var box_select_gesture_smoke_script := load("res://source/world/BoxSelectGestureSmoke.gd") as Script
	if box_select_gesture_smoke_script == null:
		_fail(97, "Box select gesture smoke: contract script missing")
		return
	var box_select_gesture_smoke = box_select_gesture_smoke_script.new()
	var box_select_gesture_error := str(box_select_gesture_smoke.call("run", scene))
	if not box_select_gesture_error.is_empty():
		_fail(98, "Box select gesture smoke: " + box_select_gesture_error)
		return

	print("Strategic unit smoke: 14 armies / 42 heavy representatives + radar + group movement OK")
	quit(0)
