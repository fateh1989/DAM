extends RefCounted

const WORLD_SOURCE := "res://source/world/MiddleEastTerrain.gd"
const GEO_SMOKE := "res://source/world/GeoOverlaySmoke.gd"
const OLD_STRATEGIC_SMOKE := "res://source/world/StrategicViewSmoke.gd"

func _function_block(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 5)
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)

func run(_scene: Node) -> String:
	if FileAccess.file_exists(OLD_STRATEGIC_SMOKE):
		return "obsolete StrategicViewSmoke still exists"

	var world := FileAccess.get_file_as_string(WORLD_SOURCE)
	if world.is_empty():
		return "world source missing"
	var camera_block := _function_block(world, "_position_camera")
	if "PROJECTION_ORTHOGONAL" in camera_block:
		return "active camera still contains orthographic overview"
	if "_is_strategic_map" in camera_block or "_is_tactical_overview" in camera_block:
		return "active camera still contains legacy mode branch"
	var pan_block := _function_block(world, "_pan_from_screen_delta")
	if "camera.size" in pan_block:
		return "active pan still depends on legacy map camera size"

	var geo_smoke := FileAccess.get_file_as_string(GEO_SMOKE)
	if "START BATTLE" in geo_smoke:
		return "geography smoke still requires START BATTLE"
	if "TacticalBattle" in geo_smoke:
		return "geography smoke still requires separate tactical scene"
	return ""
