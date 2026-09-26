extends RefCounted

func run(scene: Node) -> String:
	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "logical combat smoke cannot access GameState"

	var governorate_index := int(scene.get("_governorate_index"))
	var roster_units: Array = game_state.call("get_heavy_units_for_governorate", governorate_index, true)
	var tanks: Array[String] = []
	for raw_unit in roster_units:
		var unit: Dictionary = raw_unit
		if str(unit.get("unit_type", "")) != "tank":
			continue
		var unit_id := str(unit.get("id", ""))
		if not unit_id.is_empty():
			tanks.append(unit_id)
		if tanks.size() >= 6:
			break
	if tanks.size() < 2:
		return "logical combat smoke cannot find two live tanks"

	var attacker_id := tanks[0]
	var target_id := tanks[1]
	var counts_before: Dictionary = game_state.call("get_heavy_force_counts")
	var target_before: Dictionary = game_state.call("get_heavy_unit", target_id)
	var hp_before := float(target_before.get("hp", 0.0))
	if hp_before <= 0.0:
		return "logical combat target starts without hit points"

	var first: Dictionary = scene.call("resolve_logical_heavy_attack", attacker_id, target_id, "tank_cannon")
	if not bool(first.get("ok", false)):
		return "logical combat first shot failed: " + str(first.get("reason", "unknown"))
	if bool(first.get("destroyed", false)):
		return "logical combat first shot unexpectedly destroyed full-health tank"

	var after_first: Dictionary = game_state.call("get_heavy_unit", target_id)
	var hp_after_first := float(after_first.get("hp", 0.0))
	if hp_after_first <= 0.0 or hp_after_first >= hp_before:
		return "logical combat partial damage did not persist"
	if not bool(after_first.get("alive", false)):
		return "logical combat partial damage incorrectly killed target"

	var destroyed := false
	for shot_index in range(12):
		var result: Dictionary = scene.call("resolve_logical_heavy_attack", attacker_id, target_id, "tank_cannon")
		if not bool(result.get("ok", false)):
			return "logical combat follow-up shot failed: " + str(result.get("reason", "unknown"))
		if bool(result.get("destroyed", false)):
			destroyed = true
			break
	if not destroyed:
		return "logical combat did not destroy target within expected repeated shots"

	var target_after: Dictionary = game_state.call("get_heavy_unit", target_id)
	if bool(target_after.get("alive", true)):
		return "destroyed logical combat target remained alive in roster"
	if float(target_after.get("hp", 1.0)) != 0.0:
		return "destroyed logical combat target retained hit points"

	var counts_after: Dictionary = game_state.call("get_heavy_force_counts")
	if int(counts_after.get("tank", 0)) != int(counts_before.get("tank", 0)) - 1:
		return "logical combat destruction did not reduce live tank count"
	if int(counts_after.get("total", 0)) != int(counts_before.get("total", 0)) - 1:
		return "logical combat destruction did not reduce total live heavy count"

	var country: Dictionary = game_state.call("get_country_snapshot", "syria")
	var destroyed_inventory: Dictionary = country.get("destroyed", {})
	if int(destroyed_inventory.get("tank", 0)) <= 0:
		return "logical combat destruction did not update combat inventory losses"

	scene.call("_set_rts_zoom_level", 8)
	var detail_root := scene.get_node_or_null("DetailedUnits")
	if detail_root != null:
		for child in detail_root.get_children():
			if child is Node3D and str(child.get_meta("logical_unit_id", "")) == target_id:
				if child.visible:
					return "destroyed logical combat target remained visible in detail LOD"

	return ""
