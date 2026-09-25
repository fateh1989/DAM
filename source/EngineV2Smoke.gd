extends SceneTree

func _initialize() -> void:
	var version := Engine.get_version_info()
	var version_string := str(version.get("string", "unknown"))
	var major := int(version.get("major", -1))
	var minor := int(version.get("minor", -1))
	var patch := int(version.get("patch", -1))

	var desktop_method := str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "")
	)
	var mobile_method := str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "")
	)

	print(
		"DAM Engine v2 • Godot=", version_string,
		" • renderer=", desktop_method,
		" • mobile_renderer=", mobile_method
	)

	if major != 4 or minor != 7 or patch < 2:
		push_error("DAM Engine v2 requires Godot 4.7.2 or newer 4.7 maintenance release")
		quit(2)
		return

	if desktop_method != "mobile":
		push_error("DAM Engine v2 desktop renderer is not Mobile/Vulkan")
		quit(3)
		return

	if mobile_method != "mobile":
		push_error("DAM Engine v2 Android renderer is not Mobile/Vulkan")
		quit(4)
		return

	quit(0)
