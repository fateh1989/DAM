extends RefCounted

func run(scene: Node) -> String:
	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "partial damage persistence cannot access GameState"

	var units: Array = scene.get("_units")
	if units.size() <= 3:
		return "partial damage persistence does not have two tank representatives"

	var attacker_index := 0
	var target_index := 3
	var attacker: Dictionary = units[attacker_index]
	var target: Dictionary = units[target_index]
	if str(attacker.get("unit_type", "")) != "tank":
		return "partial damage attacker is not a tank"
	if str(target.get("unit_type", "")) != "tank":
		return "partial damage target is not a tank"
	if not bool(attacker.get("alive", false)) or not bool(target.get("alive", false)):
		return "partial damage verification tanks are not alive"

	var logical_id := str(target.get("logical_unit_id", ""))
	if logical_id.is_empty():
		return "partial damage target has no logical id"
	var logical_before: Dictionary = game_state.call("get_heavy_unit", logical_id)
	if logical_before.is_empty():
		return "partial damage logical target is missing"
	var hp_before := float(logical_before.get("hp", 0.0))
	var max_hp := float(logical_before.get("max_hp", 0.0))
	if hp_before <= 0.0 or absf(hp_before - max_hp) > 0.001:
		return "partial damage target did not start at full persistent health"

	var counts_before: Dictionary = game_state.call("get_heavy_force_counts")
	var result: Dictionary = scene.call("resolve_unit_attack", attacker_index, target_index, "tank_cannon")
	if not bool(result.get("ok", false)):
		return "partial damage verification shot failed: " + str(result.get("reason", "unknown"))
	if bool(result.get("destroyed", false)):
		return "partial damage verification shot unexpectedly destroyed target"

	units = scene.get("_units")
	var visible_after: Dictionary = units[target_index]
	var visible_hp := float(visible_after.get("hp", 0.0))
	if visible_hp <= 0.0 or visible_hp >= hp_before:
		return "visible target did not retain partial damage"

	var logical_after: Dictionary = game_state.call("get_heavy_unit", logical_id)
	if logical_after.is_empty() or not bool(logical_after.get("alive", false)):
		return "partially damaged logical target is missing or dead"
	var logical_hp := float(logical_after.get("hp", 0.0))
	if absf(logical_hp - visible_hp) > 0.001:
		return "persistent logical HP differs from visible partial damage"
	if logical_hp >= hp_before:
		return "persistent logical HP did not decrease"

	var counts_after: Dictionary = game_state.call("get_heavy_force_counts")
	if int(counts_after.get("total", 0)) != int(counts_before.get("total", 0)):
		return "partial damage incorrectly changed live heavy force count"
	if int(counts_after.get("tank", 0)) != int(counts_before.get("tank", 0)):
		return "partial damage incorrectly changed live tank count"

	return ""
