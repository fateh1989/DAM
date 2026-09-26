extends RefCounted

func run(scene: Node) -> String:
	var game_state: Node = scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "selected attack smoke cannot access GameState"
	var units: Array = scene.get("_units")
	if units.size() < 6:
		return "selected attack smoke has too few representative units"
	var attacker_index := 0
	var friendly_index := 1
	var target_index := 3
	var attacker: Dictionary = units[attacker_index]
	var friendly: Dictionary = units[friendly_index]
	var target: Dictionary = units[target_index]
	if int(attacker.get("army_id", -1)) != int(friendly.get("army_id", -2)):
		return "selected attack smoke expected same-army friendly unit"
	if int(attacker.get("army_id", -1)) == int(target.get("army_id", -1)):
		return "selected attack smoke target is not an enemy army"
	var friendly_result: Dictionary = scene.call("resolve_unit_attack", attacker_index, friendly_index, "tank_cannon")
	if bool(friendly_result.get("ok", false)) or str(friendly_result.get("reason", "")) != "friendly_target":
		return "friendly-fire guard did not reject same-army target"
	var target_id := str(target.get("logical_unit_id", ""))
	var original_lon := float(target.get("lon", 0.0))
	var original_lat := float(target.get("lat", 0.0))
	var before_hp := float(target.get("hp", 0.0))
	var close_lon := float(attacker.get("lon", 0.0)) + 0.004
	var close_lat := float(attacker.get("lat", 0.0))
	if target_id.is_empty() or not bool(game_state.call("update_heavy_unit_position", target_id, close_lon, close_lat)):
		return "selected attack smoke could not position target within range"
	target["lon"] = close_lon
	target["lat"] = close_lat
	target["target_lon"] = close_lon
	target["target_lat"] = close_lat
	units[target_index] = target
	scene.set("_units", units)
	scene.call("clear_selected_units")
	if not bool(scene.call("select_single_unit", attacker_index)):
		return "selected attack smoke could not select attacker"
	if int(scene.call("issue_selected_attack", target_index)) != 1:
		return "selected attack command did not fire once"
	units = scene.get("_units")
	var target_after: Dictionary = units[target_index]
	if float(target_after.get("hp", before_hp)) >= before_hp:
		return "selected attack command did not damage enemy target"
	if not bool(target_after.get("alive", false)):
		return "selected attack verification target was destroyed unexpectedly"
	game_state.call("update_heavy_surviving_hp", target_id, before_hp)
	game_state.call("update_heavy_unit_position", target_id, original_lon, original_lat)
	target_after["hp"] = before_hp
	target_after["lon"] = original_lon
	target_after["lat"] = original_lat
	target_after["target_lon"] = original_lon
	target_after["target_lat"] = original_lat
	var combat_state: Dictionary = target_after.get("combat_state", {})
	if not combat_state.is_empty():
		combat_state["hp"] = before_hp
		combat_state["alive"] = true
		target_after["combat_state"] = combat_state
	units[target_index] = target_after
	scene.set("_units", units)
	scene.call("_sync_unit_visuals")
	scene.call("clear_selected_units")
	return ""
