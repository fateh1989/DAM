extends RefCounted

const HEAVY_FORCE_ROSTER_SCRIPT := preload("res://source/state/HeavyForceRoster.gd")

func run(scene: Node) -> String:
	var original: Dictionary = scene.get("_hydrology_data")
	var fake := {
		"source": "test",
		"rivers": [{
			"id": "river:test",
			"name": "الفرات الاختباري",
			"waterway": "river",
			"blocking": true,
			"width_m": 300.0,
			"points": [[37.0, 35.0], [37.0, 36.0]],
		}],
		"crossings": [{
			"kind": "bridge",
			"river_id": "river:test",
			"river_name": "الفرات الاختباري",
			"lon": 37.0,
			"lat": 35.5,
		}],
	}
	scene.set("_hydrology_data", fake)

	var start := Vector2(36.8, 35.35)
	var destination := Vector2(37.2, 35.35)
	var routed: Array[Vector2] = scene.call("plan_ground_route", start, destination)
	if routed.size() != 2:
		scene.set("_hydrology_data", original)
		return "river crossing route did not insert exactly one legal bridge waypoint"
	if routed[0].distance_to(Vector2(37.0, 35.5)) > 0.00001:
		scene.set("_hydrology_data", original)
		return "river crossing route did not use the legal bridge"

	var bridge_line: Array[Vector2] = scene.call("plan_ground_route", Vector2(36.8, 35.5), Vector2(37.2, 35.5))
	if bridge_line.size() != 1:
		scene.set("_hydrology_data", original)
		return "movement through a legal bridge was incorrectly rerouted"

	var grouped := {
		"source": "group-test",
		"rivers": [
			{
				"id": "way:euphrates-a",
				"river_group": "river:euphrates",
				"name": "الفرات",
				"waterway": "river",
				"blocking": true,
				"width_m": 300.0,
				"points": [[37.0, 35.0], [37.0, 35.4]],
			},
			{
				"id": "way:euphrates-b",
				"river_group": "river:euphrates",
				"name": "الفرات",
				"waterway": "river",
				"blocking": true,
				"width_m": 300.0,
				"points": [[37.0, 35.6], [37.0, 36.0]],
			},
		],
		"crossings": [{
			"kind": "bridge",
			"river_id": "way:euphrates-a",
			"river_group": "river:euphrates",
			"river_name": "الفرات",
			"lon": 37.0,
			"lat": 35.2,
		}],
	}
	scene.set("_hydrology_data", grouped)
	var grouped_route: Array[Vector2] = scene.call(
		"plan_ground_route",
		Vector2(36.8, 35.8),
		Vector2(37.2, 35.8)
	)
	if grouped_route.size() != 2:
		scene.set("_hydrology_data", original)
		return "separate OSM segments of the same river did not share legal crossings"
	if grouped_route[0].distance_to(Vector2(37.0, 35.2)) > 0.00001:
		scene.set("_hydrology_data", original)
		return "movement across second river segment did not use first-segment bridge"
	var grouped_crossings: Array = scene.call("_crossings_for_river", "river:euphrates")
	if grouped_crossings.size() != 1:
		scene.set("_hydrology_data", original)
		return "whole-river crossing lookup did not merge OSM river segments"

	scene.set("_hydrology_data", fake)
	fake["crossings"] = []
	scene.set("_hydrology_data", fake)
	var blocked: Array[Vector2] = scene.call("plan_ground_route", start, destination)
	if not blocked.is_empty():
		scene.set("_hydrology_data", original)
		return "army can still cross a blocking river without bridge or ford"

	var roster = HEAVY_FORCE_ROSTER_SCRIPT.new()
	var specs := {
		"tank": {"hp": 100.0, "speed_km_sec": 1.0},
		"rocket_launcher": {"hp": 100.0, "speed_km_sec": 1.0},
		"artillery": {"hp": 100.0, "speed_km_sec": 1.0},
	}
	if not roster.seed(scene.GOVERNORATES, specs):
		scene.set("_hydrology_data", original)
		return "heavy route smoke could not seed persistent force"
	var unit_id := "G01-tank-001"
	var unit: Dictionary = roster.get_unit(unit_id)
	var a := Vector2(float(unit["lon"]) + 0.0005, float(unit["lat"]))
	var b := Vector2(float(unit["lon"]) + 0.0010, float(unit["lat"]))
	if not roster.issue_route(unit_id, [a, b]):
		scene.set("_hydrology_data", original)
		return "persistent heavy unit rejected waypoint route"
	var queued: Dictionary = roster.get_unit(unit_id)
	if absf(float(queued["target_lon"]) - a.x) > 0.000001 or (queued.get("route_points", []) as Array).size() != 1:
		scene.set("_hydrology_data", original)
		return "persistent heavy unit did not queue bridge waypoint"
	roster.tick_movement(0.20)
	var advanced: Dictionary = roster.get_unit(unit_id)
	if absf(float(advanced["target_lon"]) - b.x) > 0.000001 or not bool(advanced["moving"]):
		scene.set("_hydrology_data", original)
		return "persistent heavy unit did not advance beyond first waypoint"
	roster.tick_movement(0.20)
	var finished: Dictionary = roster.get_unit(unit_id)
	if bool(finished["moving"]):
		scene.set("_hydrology_data", original)
		return "persistent heavy unit did not finish waypoint route"

	scene.set("_hydrology_data", original)
	return ""
