extends RefCounted

const HEAVY_FORCE_ROSTER_SCRIPT := preload("res://source/state/HeavyForceRoster.gd")

func run(scene: Node) -> String:
	var roster = HEAVY_FORCE_ROSTER_SCRIPT.new()
	var specs := {
		"tank": {"hp": 100.0, "speed_km_sec": 1.0},
		"rocket_launcher": {"hp": 100.0, "speed_km_sec": 1.0},
		"artillery": {"hp": 100.0, "speed_km_sec": 1.0},
	}
	if not roster.seed(scene.GOVERNORATES, specs):
		return "route queue smoke could not seed heavy roster"
	var unit_id := "G01-tank-001"
	var before: Dictionary = roster.get_unit(unit_id)
	var start := Vector2(float(before["lon"]), float(before["lat"]))
	var first := Vector2(start.x + 0.01, start.y)
	var second := Vector2(start.x + 0.02, start.y + 0.005)
	var route := [
		start,
		Vector2(start.x + 0.000000001, start.y),
		Vector2(999.0, 999.0),
		first,
		first,
		second,
	]
	if not roster.issue_route(unit_id, route):
		return "route queue rejected normalized heavy route"
	var queued: Dictionary = roster.get_unit(unit_id)
	if absf(float(queued["target_lon"]) - first.x) > 0.000001 or absf(float(queued["target_lat"]) - first.y) > 0.000001:
		return "route queue did not skip current or invalid waypoints"
	var pending: Array = queued.get("route_points", [])
	if pending.size() != 1:
		return "route queue did not collapse duplicate waypoints"
	var remaining: Dictionary = pending[0]
	if absf(float(remaining["lon"]) - second.x) > 0.000001 or absf(float(remaining["lat"]) - second.y) > 0.000001:
		return "route queue lost the final valid waypoint"
	if absf(float(queued.get("heading_rad", 0.0))) < 0.10:
		return "heavy unit did not turn toward route immediately"
	return ""
