extends RefCounted

const LANDMARK_SCRIPT := preload("res://source/world/ProvinceLandmark.gd")

func run(scene: Node) -> String:
	var item := LANDMARK_SCRIPT.new()
	item.setup(2, "قلعة حلب", "Citadel of Aleppo", "citadel")
	if item.governorate_index != 2:
		return "landmark lost governorate index"
	if item.landmark_name_ar != "قلعة حلب":
		return "landmark lost Arabic name"
	if item.get_node_or_null("Body") == null:
		return "landmark procedural body was not created"
	item.free()
	var landmarks: Array = scene.call("get_province_landmarks")
	if landmarks.size() != 14:
		return "final landmark batch did not create fourteen landmarks"
	if str(landmarks[2].landmark_name_ar) != "قلعة حلب":
		return "Aleppo landmark is not Citadel of Aleppo"
	var catalog_error := str(scene.call("validate_province_landmark_catalog"))
	if not catalog_error.is_empty():
		return catalog_error
	var seen := {}
	for landmark_item in landmarks:
		var province_index := int(landmark_item.governorate_index)
		if seen.has(province_index):
			return "runtime landmarks contain duplicate governorates"
		seen[province_index] = true
	if seen.size() != 14:
		return "runtime landmarks do not cover all governorates"
	scene.set("_terrain_mode", true)
	scene.set("_rts_zoom_level", 4)
	scene.call("_sync_landmark_labels")
	var label := landmarks[0].get_node_or_null("LandmarkLabel") as Label3D
	if label == null or not label.visible:
		return "landmark labels are not visible at close RTS zoom"
	scene.set("_rts_zoom_level", 1)
	scene.call("_sync_landmark_labels")
	if label.visible:
		return "landmark labels remain visible at distant RTS zoom"
	scene.set("_governorate_index", 2)
	scene.call("_sync_landmark_selection")
	if not bool(landmarks[2].selected_landmark):
		return "focused governorate landmark is not highlighted"
	if bool(landmarks[1].selected_landmark):
		return "non-focused governorate landmark is incorrectly highlighted"
	return ""
