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

	var city_smoke_script := load("res://source/world/MiniatureCitySmoke.gd") as Script
	if city_smoke_script == null:
		_fail(70, "Miniature city smoke: contract script missing")
		return
	var city_smoke = city_smoke_script.new()
	var city_error := str(city_smoke.call("run", scene))
	if not city_error.is_empty():
		_fail(71, "Miniature city smoke: " + city_error)
		return

	var heavy_weapon_smoke_script := load("res://source/world/HeavyWeaponSmoke.gd") as Script
	if heavy_weapon_smoke_script == null:
		_fail(72, "Heavy weapon smoke: contract script missing")
		return
	var heavy_weapon_smoke = heavy_weapon_smoke_script.new()
	var heavy_weapon_error := str(heavy_weapon_smoke.call("run", scene))
	if not heavy_weapon_error.is_empty():
		_fail(73, "Heavy weapon smoke: " + heavy_weapon_error)
		return

	var battle_terrain_smoke_script := load("res://source/battle/BattleTerrainSmoke.gd") as Script
	if battle_terrain_smoke_script == null:
		_fail(66, "Battle terrain smoke: contract script missing")
		return
	var battle_terrain_smoke = battle_terrain_smoke_script.new()
	var battle_terrain_error := str(battle_terrain_smoke.call("run", scene))
	if not battle_terrain_error.is_empty():
		_fail(67, "Battle terrain smoke: " + battle_terrain_error)
		return

	var battle_zoom_smoke_script := load("res://source/battle/BattleZoomSmoke.gd") as Script
	if battle_zoom_smoke_script == null:
		_fail(68, "Battle zoom smoke: contract script missing")
		return
	var battle_zoom_smoke = battle_zoom_smoke_script.new()
	var battle_zoom_error := str(battle_zoom_smoke.call("run", scene))
	if not battle_zoom_error.is_empty():
		_fail(69, "Battle zoom smoke: " + battle_zoom_error)
		return

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
	if scene.get_selected_unit_count() != 14:
		_fail(27, "Strategic unit smoke: select all command button failed")
		return
	if "SELECTED 14" not in scene.status_label.text:
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
	if radar_units.size() != 14:
		_fail(9, "Strategic unit smoke: radar does not mirror active armies")
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

	print("Strategic unit smoke: 14 armies + radar + group movement OK")
	quit(0)
