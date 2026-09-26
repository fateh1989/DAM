extends RefCounted

func run(scene: Node) -> String:
	var game_state := scene.get_node_or_null("/root/GameState")
	if game_state == null:
		return "GameState autoload is missing"

	var counts: Dictionary = game_state.call("get_heavy_force_counts")
	if int(counts.get("total", 0)) != 1400:
		return "live heavy roster total is not 1400"
	if int(counts.get("tank", 0)) != 700:
		return "live tank roster total is not 700"
	if int(counts.get("rocket_launcher", 0)) != 280:
		return "live rocket launcher roster total is not 280"
	if int(counts.get("artillery", 0)) != 420:
		return "live artillery roster total is not 420"

	var country: Dictionary = game_state.call("get_country_snapshot", "syria")
	var deployed: Dictionary = country.get("deployed", {})
	if int(deployed.get("tank", 0)) != 700:
		return "combat inventory did not deploy 700 tanks"
	if int(deployed.get("rocket_launcher", 0)) != 280:
		return "combat inventory did not deploy 280 rocket launchers"
	if int(deployed.get("artillery", 0)) != 420:
		return "combat inventory did not deploy 420 artillery units"

	var units: Array = scene.get("_units")
	if units.size() != 42:
		return "visible heavy representative count is not 42"
	var seen_ids := {}
	for raw_unit in units:
		var unit: Dictionary = raw_unit
		var logical_id := str(unit.get("logical_unit_id", ""))
		if logical_id.is_empty():
			return "visible heavy representative is missing logical unit id"
		if seen_ids.has(logical_id):
			return "two visible representatives share the same logical unit id"
		seen_ids[logical_id] = true
		var logical: Dictionary = game_state.call("get_heavy_unit", logical_id)
		if logical.is_empty():
			return "visible representative points to missing logical unit"
		if str(logical.get("unit_type", "")) != str(unit.get("unit_type", "")):
			return "visible representative unit type does not match logical roster"
		if int(logical.get("home_governorate_index", -1)) != int(unit.get("governorate_index", -2)):
			return "visible representative governorate does not match logical roster"

	return ""
