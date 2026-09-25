extends SceneTree

func _initialize() -> void:
	if not ClassDB.class_exists("DAMNativeCore"):
		push_error("DAM Native Core smoke: C++ GDExtension class is missing")
		quit(2)
		return

	var core = ClassDB.instantiate("DAMNativeCore")
	if core == null:
		push_error("DAM Native Core smoke: cannot instantiate DAMNativeCore")
		quit(3)
		return

	var levels := PackedInt32Array([
		0, 0, 1,
		0, 1, 2,
		1, 2, 3,
	])
	var result: Dictionary = core.call("analyze_cells", levels, 2, 1)
	var averages: PackedInt32Array = result.get("averages", PackedInt32Array())
	var slopes: PackedInt32Array = result.get("slopes", PackedInt32Array())

	if averages.size() != 4 or slopes.size() != 4:
		push_error("DAM Native Core smoke: invalid chunk analysis output")
		quit(4)
		return

	if not bool(result.get("native", false)):
		push_error("DAM Native Core smoke: native marker missing")
		quit(5)
		return

	print(
		core.call("engine_tag"),
		" • cells=", averages.size(),
		" • cliff_edges=", int(result.get("cliff_edges", -1))
	)
	quit(0)
