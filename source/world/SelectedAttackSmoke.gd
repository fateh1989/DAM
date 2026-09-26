extends RefCounted

func run(scene: Node) -> String:
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
	scene.call("clear_selected_units")
	if not bool(scene.call("select_single_unit", attacker_index)):
		return "selected attack smoke could not select attacker"
	var before_hp := float(target.get("hp", 0.0))
	if int(scene.call("issue_selected_attack", target_index)) != 1:
		return "selected attack command did not fire once"
	units = scene.get("_units")
	var target_after: Dictionary = units[target_index]
	if float(target_after.get("hp", before_hp)) >= before_hp:
		return "selected attack command did not damage enemy target"
	if not bool(target_after.get("alive", false)):
		return "selected attack verification target was destroyed unexpectedly"
	scene.call("clear_selected_units")
	return ""
