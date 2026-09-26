extends RefCounted

func run(scene: Node) -> String:
	var units: Array = scene.get("_units")
	if units.size() < 4:
		return "attack range smoke has too few representatives"
	var visible_result: Dictionary = scene.call("resolve_unit_attack", 0, 3, "tank_cannon")
	if bool(visible_result.get("ok", false)) or str(visible_result.get("reason", "")) != "out_of_range":
		return "visible heavy attack ignored tank cannon range"
	var logical_result: Dictionary = scene.call("resolve_logical_heavy_attack", "G01-tank-002", "G02-tank-002", "tank_cannon")
	if bool(logical_result.get("ok", false)) or str(logical_result.get("reason", "")) != "out_of_range":
		return "persistent heavy attack ignored tank cannon range"
	if float(visible_result.get("distance_km", 0.0)) <= float(visible_result.get("range_km", 0.0)):
		return "visible range rejection did not report a real distance overflow"
	return ""
