extends RefCounted

func run(scene: Node) -> String:
	var group: Array[int] = [0, 1, 2, 3]
	scene.call("select_units", group)
	if not bool(scene.call("issue_selected_group_move", Vector2(36.5, 35.5))):
		return "formation move was rejected"
	var first_targets: Array = scene.call("get_selected_move_targets")
	if first_targets.size() != group.size():
		return "formation target count is wrong"
	for i in range(first_targets.size()):
		for j in range(i + 1, first_targets.size()):
			var a: Vector2 = first_targets[i]
			var b: Vector2 = first_targets[j]
			if a.distance_to(b) <= 0.000001:
				return "formation stacked units"

	var units: Array = scene.get("_units")
	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "movement persistence test cannot access GameState"
	var first_visible: Dictionary = units[0]
	var first_logical_id := str(first_visible.get("logical_unit_id", ""))
	if first_logical_id.is_empty():
		return "moving representative is missing logical id"
	var first_logical: Dictionary = game_state.call("get_heavy_unit", first_logical_id)
	if first_logical.is_empty():
		return "moving representative logical state is missing"
	if absf(float(first_logical.get("lon", 0.0)) - float(first_visible.get("lon", 0.0))) > 0.000001:
		return "visible representative longitude does not start at logical position"
	if absf(float(first_logical.get("lat", 0.0)) - float(first_visible.get("lat", 0.0))) > 0.000001:
		return "visible representative latitude does not start at logical position"
	if not bool(first_logical.get("moving", false)):
		return "logical heavy unit did not receive visible move order"
	if absf(float(first_logical.get("target_lon", 0.0)) - float(first_visible.get("target_lon", 0.0))) > 0.000001:
		return "logical heavy move longitude differs from visible target"
	if absf(float(first_logical.get("target_lat", 0.0)) - float(first_visible.get("target_lat", 0.0))) > 0.000001:
		return "logical heavy move latitude differs from visible target"
	var first_serial := int((units[0] as Dictionary).get("move_order_serial", 0))
	if not bool(scene.call("issue_selected_group_move", Vector2(37.0, 35.8))):
		return "replacement move was rejected"
	units = scene.get("_units")
	var second_serial := int((units[0] as Dictionary).get("move_order_serial", 0))
	if second_serial <= first_serial:
		return "new movement did not supersede old movement"

	var stopped := int(scene.call("stop_selected_units"))
	if stopped != group.size():
		return "STOP did not report every moving selected unit"
	if not bool(scene.call("are_selected_units_stopped")):
		return "STOP left a selected unit moving"
	units = scene.get("_units")
	for index in group:
		var unit: Dictionary = units[index]
		if float(unit.get("target_lon", 0.0)) != float(unit.get("lon", 0.0)):
			return "STOP left stale longitude target"
		if float(unit.get("target_lat", 0.0)) != float(unit.get("lat", 0.0)):
			return "STOP left stale latitude target"
	var stopped_logical: Dictionary = game_state.call("get_heavy_unit", first_logical_id)
	if bool(stopped_logical.get("moving", true)):
		return "logical heavy unit remained moving after visible STOP"
	if absf(float(stopped_logical.get("target_lon", 0.0)) - float(stopped_logical.get("lon", 0.0))) > 0.000001:
		return "logical STOP left stale longitude target"
	if absf(float(stopped_logical.get("target_lat", 0.0)) - float(stopped_logical.get("lat", 0.0))) > 0.000001:
		return "logical STOP left stale latitude target"
	scene.call("clear_selected_units")
	return ""
