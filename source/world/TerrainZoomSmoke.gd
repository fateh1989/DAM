extends RefCounted

func run(scene: Node) -> String:
	if scene.RTS_ZOOM_LEVEL_MIN != 1 or scene.RTS_ZOOM_LEVEL_MAX != 5:
		return "RTS terrain zoom range is not five levels"
	if scene.RTS_ZOOM_DISTANCE_SCALES.size() != 5:
		return "RTS terrain zoom scale table does not contain five levels"
	return ""
