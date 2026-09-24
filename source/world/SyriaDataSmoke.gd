extends SceneTree

const GOVERNORATES := [
	"damascus","rif_dimashq","aleppo","homs","hama","latakia","tartus",
	"idlib","raqqa","deir_ez_zor","hasakah","daraa","suwayda","quneitra"
]


func _initialize() -> void:
	var total_elements := 0
	for slug in GOVERNORATES:
		var path := "res://source/world/data/syria_%s.json" % slug
		if not FileAccess.file_exists(path):
			push_error("Missing Syria dataset: " + path)
			quit(2)
			return

		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Cannot open Syria dataset: " + path)
			quit(3)
			return

		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("Invalid Syria JSON: " + path)
			quit(4)
			return

		var elements: Array = parsed.get("elements", [])
		print(slug, " elements=", elements.size())
		if elements.size() < 20:
			push_error("Syria sector too sparse: " + slug)
			quit(5)
			return
		total_elements += elements.size()

	print("Syria data smoke: governorates=", GOVERNORATES.size(), " elements=", total_elements)
	quit(0)
