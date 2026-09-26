extends RefCounted

func _find_direct_child(root: Node, child_name: String) -> Node:
	for child in root.get_children():
		if str(child.name) == child_name:
			return child
	return null


func run(scene: Node) -> String:
	var original_data: Dictionary = scene.get("_hydrology_data").duplicate(true)
	var original_origin := Vector2(float(scene.get("_origin_lon")), float(scene.get("_origin_lat")))
	var fake := {
		"source": "visual-smoke",
		"rivers": [{
			"id": "river:visual",
			"name": "الفرات الاختباري",
			"waterway": "river",
			"blocking": true,
			"width_m": 260.0,
			"points": [[39.0, 35.0], [39.0, 36.0]],
		}],
		"crossings": [
			{
				"kind": "bridge",
				"river_id": "river:visual",
				"river_name": "الفرات الاختباري",
				"source_id": "way:bridge-smoke",
				"road_class": "primary",
				"lon": 39.0,
				"lat": 35.35,
				"heading_rad": 0.62,
				"bridge_length_m": 340.0,
			},
			{
				"kind": "ford",
				"river_id": "river:visual",
				"river_name": "الفرات الاختباري",
				"source_id": "node:ford-smoke",
				"lon": 39.0,
				"lat": 35.72,
			},
		],
	}
	scene.set("_hydrology_data", fake)
	scene.call("_refresh_hydrology", true)

	var root := scene.get_node_or_null("Hydrology")
	if root == null:
		return "hydrology visual root is missing"
	if _find_direct_child(root, "RiverBanks") == null or _find_direct_child(root, "RiverWater") == null:
		return "river banks/water were not rendered"

	var bridge := _find_direct_child(root, "BridgeCrossing") as Node3D
	if bridge == null:
		return "legal bridge has no visible world model"
	if str(bridge.get_meta("source_id", "")) != "way:bridge-smoke":
		return "bridge visual lost OSM source identity"
	if absf(bridge.rotation.y - 0.62) > 0.0001:
		return "bridge visual lost real road heading"
	if bridge.get_node_or_null("Deck") == null or bridge.get_node_or_null("RailLeft") == null or bridge.get_node_or_null("RailRight") == null:
		return "bridge visual is missing deck or rails"

	var ford := _find_direct_child(root, "FordCrossing") as Node3D
	if ford == null:
		return "legal ford has no visible world marker"
	if str(ford.get_meta("source_id", "")) != "node:ford-smoke":
		return "ford visual lost OSM source identity"
	if ford.get_node_or_null("ShallowBed") == null:
		return "ford visual is missing shallow crossing bed"

	var shifted := original_origin + Vector2(0.018, -0.014)
	scene.set("_origin_lon", shifted.x)
	scene.set("_origin_lat", shifted.y)
	scene.call("_position_camera")
	var refreshed_origin: Vector2 = scene.get("_last_hydrology_origin")
	if refreshed_origin.distance_to(shifted) > 0.000001:
		return "hydrology did not realign after world-origin movement"

	scene.set("_origin_lon", original_origin.x)
	scene.set("_origin_lat", original_origin.y)
	scene.set("_hydrology_data", original_data)
	scene.set("_last_hydrology_origin", Vector2(999.0, 999.0))
	scene.call("_refresh_hydrology", true)
	return ""
