extends RefCounted

const LANDMARK_SCRIPT := preload("res://source/world/ProvinceLandmark.gd")

func run(scene: Node) -> String:
	var item := LANDMARK_SCRIPT.new()
	item.setup(2, "حلب", "Aleppo", "city")
	if item.governorate_index != 2:
		return "city symbol lost governorate index"
	if item.landmark_name_ar != "حلب" or item.archetype != "city":
		return "city symbol lost city identity"
	var body := item.get_node_or_null("Body") as Node3D
	if body == null or body.get_child_count() < 8:
		return "city miniature does not contain enough 3D structure"
	if not bool(item.call("set_damage_state", "damaged")) or str(item.damage_state) != "damaged":
		return "city damaged state failed"
	if not bool(item.call("set_damage_state", "rubble")) or str(item.damage_state) != "rubble":
		return "city rubble state failed"
	if not bool(item.call("set_damage_state", "rebuilt")) or str(item.damage_state) != "rebuilt":
		return "city rebuilt state failed"
	if bool(item.call("set_damage_state", "invalid")):
		return "city accepted an invalid damage state"
	item.free()

	var landmarks: Array = scene.call("get_province_landmarks")
	if landmarks.size() != 14:
		return "city symbol batch did not create fourteen cities"
	var seen := {}
	for i in range(landmarks.size()):
		var city = landmarks[i]
		var province_index := int(city.governorate_index)
		if seen.has(province_index):
			return "city symbols contain duplicate governorates"
		seen[province_index] = true
		if str(city.archetype) != "city":
			return "province symbol is not a city miniature"
		var catalog: Dictionary = scene.PROVINCE_LANDMARKS[i]
		var governorate: Dictionary = scene.GOVERNORATES[i]
		if str(catalog.get("name_ar", "")) != str(governorate.get("name_ar", "")):
			return "city symbol name does not match governorate"
		if abs(float(catalog.get("lon", 0.0)) - float(governorate.get("lon", 0.0))) > 0.000001:
			return "city symbol longitude does not match governorate city anchor"
		if abs(float(catalog.get("lat", 0.0)) - float(governorate.get("lat", 0.0))) > 0.000001:
			return "city symbol latitude does not match governorate city anchor"
	if seen.size() != 14:
		return "city symbols do not cover all governorates"

	var catalog_error := str(scene.call("validate_province_landmark_catalog"))
	if not catalog_error.is_empty():
		return catalog_error

	scene.set("_terrain_mode", true)
	scene.set("_rts_zoom_level", 4)
	scene.call("_sync_landmark_labels")
	var label := landmarks[0].get_node_or_null("LandmarkLabel") as Label3D
	if label == null or not label.visible:
		return "city labels are not visible at close RTS zoom"
	scene.set("_rts_zoom_level", 1)
	scene.call("_sync_landmark_labels")
	if label.visible:
		return "city labels remain visible at distant RTS zoom"

	scene.set("_governorate_index", 2)
	scene.call("_sync_landmark_selection")
	if not bool(landmarks[2].selected_landmark):
		return "focused governorate city is not highlighted"
	if bool(landmarks[1].selected_landmark):
		return "non-focused governorate city is incorrectly highlighted"

	scene.set("_rts_zoom_level", 1)
	scene.call("_sync_landmark_lod")
	if int(landmarks[2].lod_level) != 1:
		return "distant city LOD is not active"
	var distant_body := landmarks[2].get_node_or_null("Body") as Node3D
	if distant_body == null or distant_body.scale.x < 1.0:
		return "distant city symbol is too small to recognize"

	scene.set("_terrain_mode", true)
	scene.set("_governorate_index", 2)
	scene.set("_center_lon", float(scene.GOVERNORATES[2]["lon"]))
	scene.set("_center_lat", float(scene.GOVERNORATES[2]["lat"]))
	scene.set("_origin_lon", float(scene.GOVERNORATES[2]["lon"]))
	scene.set("_origin_lat", float(scene.GOVERNORATES[2]["lat"]))
	scene.set("_rts_zoom_level", 5)
	scene.call("_sync_landmark_positions")
	if int(landmarks[2].lod_level) != 2:
		return "close city LOD is not detailed"
	var visible_count := int(scene.call("get_visible_landmark_count"))
	if visible_count < 1 or visible_count >= 14:
		return "city culling is not limiting local terrain draw cost"
	if not bool(landmarks[2].visible):
		return "focused governorate city was culled"
	return ""
