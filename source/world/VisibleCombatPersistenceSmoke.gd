extends RefCounted

func run(scene: Node) -> String:
	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "visible combat persistence cannot access GameState"

	var units: Array = scene.get("_units")
	if units.size() <= 40:
		return "visible combat persistence does not have target representative"

	var attacker_index := 0
	var target_index := 40
	var attacker: Dictionary = units[attacker_index]
	var target: Dictionary = units[target_index]
	if str(attacker.get("unit_type", "")) != "tank":
		return "visible combat attacker is not a tank"
	if str(target.get("unit_type", "")) != "artillery":
		return "visible combat target is not artillery"
	if not bool(attacker.get("alive", false)) or not bool(target.get("alive", false)):
		return "visible combat test units are not alive"

	var logical_id := str(target.get("logical_unit_id", ""))
	if logical_id.is_empty():
		return "visible combat target has no logical id"
	var logical_before: Dictionary = game_state.call("get_heavy_unit", logical_id)
	if logical_before.is_empty() or not bool(logical_before.get("alive", false)):
		return "visible combat logical target is unavailable"

	var counts_before: Dictionary = game_state.call("get_heavy_force_counts")
	var country_before: Dictionary = game_state.call("get_country_snapshot", "syria")
	var deployed_before: Dictionary = country_before.get("deployed", {})
	var destroyed_before: Dictionary = country_before.get("destroyed", {})

	var first: Dictionary = scene.call("resolve_unit_attack", attacker_index, target_index, "tank_cannon")
	if not bool(first.get("ok", false)):
		return "first persistent visible combat shot failed: " + str(first.get("reason", "unknown"))
	if bool(first.get("destroyed", false)):
		return "artillery target was destroyed by first verification shot"

	var second: Dictionary = scene.call("resolve_unit_attack", attacker_index, target_index, "tank_cannon")
	if not bool(second.get("ok", false)):
		return "second persistent visible combat shot failed: " + str(second.get("reason", "unknown"))
	if not bool(second.get("destroyed", false)):
		return "artillery target survived expected second verification shot"

	units = scene.get("_units")
	var visible_after: Dictionary = units[target_index]
	if bool(visible_after.get("alive", true)):
		return "destroyed visible artillery remained alive"

	var logical_after: Dictionary = game_state.call("get_heavy_unit", logical_id)
	if bool(logical_after.get("alive", true)):
		return "destroyed visible artillery remained alive in persistent roster"
	if float(logical_after.get("hp", 1.0)) != 0.0:
		return "destroyed logical artillery retained hit points"

	var counts_after: Dictionary = game_state.call("get_heavy_force_counts")
	if int(counts_after.get("artillery", 0)) != int(counts_before.get("artillery", 0)) - 1:
		return "visible artillery destruction did not reduce persistent artillery count"
	if int(counts_after.get("total", 0)) != int(counts_before.get("total", 0)) - 1:
		return "visible artillery destruction did not reduce persistent total"

	var country_after: Dictionary = game_state.call("get_country_snapshot", "syria")
	var deployed_after: Dictionary = country_after.get("deployed", {})
	var destroyed_after: Dictionary = country_after.get("destroyed", {})
	if int(deployed_after.get("artillery", 0)) != int(deployed_before.get("artillery", 0)) - 1:
		return "visible artillery destruction did not reduce deployed inventory"
	if int(destroyed_after.get("artillery", 0)) != int(destroyed_before.get("artillery", 0)) + 1:
		return "visible artillery destruction did not increment destroyed inventory"

	var wreck_node = visible_after.get("node")
	if not (wreck_node is Node3D) or not is_instance_valid(wreck_node):
		return "destroyed visible artillery lost its battlefield node"
	if not bool(wreck_node.get_meta("is_wreck", false)):
		return "destroyed visible artillery was not converted into wreck state"
	if not wreck_node.visible:
		return "destroyed visible artillery wreck is hidden"
	if int(scene.call("get_wreck_count")) < 1:
		return "battlefield wreck count did not increase"

	return ""
