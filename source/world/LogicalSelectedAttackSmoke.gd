extends RefCounted

func run(scene: Node) -> String:
	var game_state: Node = scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "logical selected attack smoke cannot access GameState"
	var attacker_id := "G01-tank-002"
	var friendly_id := "G01-artillery-002"
	var target_id := "G02-tank-002"
	var attacker: Dictionary = game_state.call("get_heavy_unit", attacker_id)
	var friendly: Dictionary = game_state.call("get_heavy_unit", friendly_id)
	var target: Dictionary = game_state.call("get_heavy_unit", target_id)
	if attacker.is_empty() or friendly.is_empty() or target.is_empty():
		return "logical selected attack smoke units are missing"
	var friendly_result: Dictionary = scene.call("resolve_logical_heavy_attack", attacker_id, friendly_id, "tank_cannon")
	if bool(friendly_result.get("ok", false)) or str(friendly_result.get("reason", "")) != "friendly_target":
		return "logical friendly-fire guard failed"
	scene.call("clear_selected_units")
	scene.call("clear_logical_heavy_selection")
	if not bool(scene.call("select_logical_heavy_unit", attacker_id, false)):
		return "logical selected attack smoke could not select attacker"
	var before_hp := float(target.get("hp", 0.0))
	if int(scene.call("issue_selected_logical_attack", target_id)) != 1:
		return "logical selected attack command did not fire"
	var after: Dictionary = game_state.call("get_heavy_unit", target_id)
	if float(after.get("hp", before_hp)) >= before_hp:
		return "logical selected attack did not damage enemy"
	if not bool(after.get("alive", false)):
		return "logical selected attack verification target was destroyed unexpectedly"
	scene.call("clear_logical_heavy_selection")
	return ""
