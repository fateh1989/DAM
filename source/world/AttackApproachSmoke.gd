extends RefCounted

func run(scene: Node) -> String:
	var game_state: Node = scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "attack approach smoke cannot access GameState"
	var units: Array = scene.get("_units")
	if units.size() < 4:
		return "attack approach smoke has too few representatives"
	var attacker_index := 0
	var target_index := 3
	var attacker: Dictionary = units[attacker_index]
	var target: Dictionary = units[target_index]
	var attacker_id := str(attacker.get("logical_unit_id", ""))
	var target_id := str(target.get("logical_unit_id", ""))
	if attacker_id.is_empty() or target_id.is_empty():
		return "attack approach smoke representatives have no logical ids"
	var attacker_lon := float(attacker.get("lon", 0.0))
	var attacker_lat := float(attacker.get("lat", 0.0))
	var target_lon := float(target.get("lon", 0.0))
	var target_lat := float(target.get("lat", 0.0))
	var target_hp := float(target.get("hp", 0.0))
	var staged_target_lon := attacker_lon + 0.026
	if not bool(game_state.call("update_heavy_unit_position", target_id, staged_target_lon, attacker_lat)):
		return "attack approach smoke could not stage enemy outside range"
	target["lon"] = staged_target_lon
	target["lat"] = attacker_lat
	target["target_lon"] = staged_target_lon
	target["target_lat"] = attacker_lat
	units[target_index] = target
	scene.set("_units", units)
	scene.call("clear_selected_units")
	if not bool(scene.call("select_single_unit", attacker_index)):
		return "attack approach smoke could not select attacker"
	if int(scene.call("issue_selected_attack", target_index)) != 1:
		return "out-of-range attack did not queue approach"
	units = scene.get("_units")
	attacker = units[attacker_index]
	if not bool(attacker.get("moving", false)) or int(attacker.get("attack_target_index", -1)) != target_index:
		return "queued attack did not retain target while approaching"
	var firing_lon := staged_target_lon - 0.006
	if not bool(game_state.call("update_heavy_unit_position", attacker_id, firing_lon, attacker_lat)):
		return "attack approach smoke could not stage attacker inside range"
	attacker["lon"] = firing_lon
	attacker["lat"] = attacker_lat
	attacker["moving"] = false
	units[attacker_index] = attacker
	scene.set("_units", units)
	if int(scene.call("_resolve_pending_visible_attacks")) != 1:
		return "queued attack did not fire after entering range"
	units = scene.get("_units")
	var target_after: Dictionary = units[target_index]
	var attacker_after: Dictionary = units[attacker_index]
	if float(target_after.get("hp", target_hp)) >= target_hp:
		return "queued attack fired without damaging target"
	if attacker_after.has("attack_target_index"):
		return "queued attack target remained after firing"
	game_state.call("update_heavy_surviving_hp", target_id, target_hp)
	game_state.call("update_heavy_unit_position", target_id, target_lon, target_lat)
	game_state.call("update_heavy_unit_position", attacker_id, attacker_lon, attacker_lat)
	target_after["hp"] = target_hp
	target_after["lon"] = target_lon
	target_after["lat"] = target_lat
	target_after["target_lon"] = target_lon
	target_after["target_lat"] = target_lat
	var target_combat: Dictionary = target_after.get("combat_state", {})
	if not target_combat.is_empty():
		target_combat["hp"] = target_hp
		target_combat["alive"] = true
		target_after["combat_state"] = target_combat
	attacker_after["lon"] = attacker_lon
	attacker_after["lat"] = attacker_lat
	attacker_after["target_lon"] = attacker_lon
	attacker_after["target_lat"] = attacker_lat
	attacker_after["moving"] = false
	units[target_index] = target_after
	units[attacker_index] = attacker_after
	scene.set("_units", units)
	scene.call("clear_selected_units")
	scene.call("_sync_unit_visuals")
	return ""
