extends RefCounted

func run(scene: Node) -> String:
	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "heavy movement persistence cannot access GameState"

	var units: Array = scene.get("_units")
	if units.is_empty():
		return "heavy movement persistence has no visible representatives"

	var first: Dictionary = units[0]
	var logical_id := str(first.get("logical_unit_id", ""))
	if logical_id.is_empty():
		return "heavy movement persistence representative has no logical id"

	var start := Vector2(float(first.get("lon", 0.0)), float(first.get("lat", 0.0)))
	scene.call("clear_selected_units")
	scene.call("select_single_unit", 0)
	var destination := Vector2(start.x + 0.02, start.y)
	if not bool(scene.call("issue_selected_group_move", destination)):
		return "heavy movement persistence move order was rejected"

	scene.call("_process", 0.05)
	units = scene.get("_units")
	var visible_after: Dictionary = units[0]
	var logical_after: Dictionary = game_state.call("get_heavy_unit", logical_id)
	var visible_position := Vector2(
		float(visible_after.get("lon", 0.0)),
		float(visible_after.get("lat", 0.0))
	)
	var logical_position := Vector2(
		float(logical_after.get("lon", 0.0)),
		float(logical_after.get("lat", 0.0))
	)
	if visible_position.distance_to(start) <= 0.000001:
		return "visible representative did not advance during persistence test"
	if logical_position.distance_to(visible_position) > 0.000001:
		return "logical heavy position did not follow visible movement"
	if not bool(logical_after.get("moving", false)):
		return "logical heavy moving state ended before visible movement"

	scene.call("stop_selected_units")
	var stopped_logical: Dictionary = game_state.call("get_heavy_unit", logical_id)
	if bool(stopped_logical.get("moving", true)):
		return "logical heavy state remained moving after STOP"
	if absf(float(stopped_logical.get("target_lon", 0.0)) - float(stopped_logical.get("lon", 0.0))) > 0.000001:
		return "logical STOP did not collapse longitude target to current position"
	if absf(float(stopped_logical.get("target_lat", 0.0)) - float(stopped_logical.get("lat", 0.0))) > 0.000001:
		return "logical STOP did not collapse latitude target to current position"

	units = scene.get("_units")
	var arrival_start_unit: Dictionary = units[0]
	var arrival_start := Vector2(
		float(arrival_start_unit.get("lon", 0.0)),
		float(arrival_start_unit.get("lat", 0.0))
	)
	var arrival_destination := Vector2(arrival_start.x + 0.000001, arrival_start.y)
	if not bool(scene.call("issue_selected_group_move", arrival_destination)):
		return "heavy movement arrival order was rejected"
	scene.call("_process", 1.0)

	units = scene.get("_units")
	var visible_final: Dictionary = units[0]
	var logical_final: Dictionary = game_state.call("get_heavy_unit", logical_id)
	if bool(visible_final.get("moving", true)):
		return "visible representative did not stop after reaching tiny destination"
	if bool(logical_final.get("moving", true)):
		return "logical heavy state did not stop after visible arrival"
	var visible_final_position := Vector2(
		float(visible_final.get("lon", 0.0)),
		float(visible_final.get("lat", 0.0))
	)
	var logical_final_position := Vector2(
		float(logical_final.get("lon", 0.0)),
		float(logical_final.get("lat", 0.0))
	)
	if logical_final_position.distance_to(visible_final_position) > 0.000001:
		return "logical heavy final position differs from visible arrival"
	if logical_final_position.distance_to(arrival_destination) > 0.000001:
		return "logical heavy unit did not reach ordered arrival point"

	scene.call("clear_selected_units")
	return ""
