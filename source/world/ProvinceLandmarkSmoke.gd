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
	return ""
