extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _fail(code: int, message: String) -> void:
	push_error(message)
	quit(code)


func _visible_world_fits(scene) -> bool:
	var viewport: Vector2 = scene.get_viewport().get_visible_rect().size
	var aspect: float = maxf(0.2, float(viewport.x) / maxf(1.0, float(viewport.y)))
	var half_h_km: float = float(scene.camera.size) * 0.5
	var half_w_km: float = float(scene.camera.size) * aspect * 0.5
	var half_lat: float = rad_to_deg(half_h_km / float(scene.EARTH_RADIUS_KM))
	var lon_radius: float = float(scene.EARTH_RADIUS_KM) * maxf(0.15, cos(deg_to_rad(float(scene._center_lat))))
	var half_lon: float = rad_to_deg(half_w_km / lon_radius)
	return (
		float(scene._center_lat) - half_lat >= float(scene.REGION_SOUTH) - 0.02
		and float(scene._center_lat) + half_lat <= float(scene.REGION_NORTH) + 0.02
		and float(scene._center_lon) - half_lon >= float(scene.REGION_WEST) - 0.02
		and float(scene._center_lon) + half_lon <= float(scene.REGION_EAST) + 0.02
	)


func _run() -> void:
	var packed := load("res://source/world/MiddleEastTerrain.tscn")
	if packed == null:
		_fail(2, "Geo overlay smoke: scene load failed")
		return

	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame

	if scene._geo_overlay_data.is_empty():
		_fail(3, "Geo overlay smoke: generated Syria overlay data is missing")
		return
	if scene._geo_overlay_data.get("boundaries", []).size() < 1:
		_fail(4, "Geo overlay smoke: no administrative boundary geometry")
		return
	if scene._geo_overlay_data.get("labels", []).size() < 10:
		_fail(5, "Geo overlay smoke: too few geographic labels")
		return

	scene._on_mode_pressed()
	await process_frame
	scene._on_zoom_wheel_changed(8.0)
	await process_frame

	if not scene._terrain_mode or not scene._is_tactical_overview():
		_fail(6, "Geo overlay smoke: Z8 is not staying in RTS terrain mode")
		return
	if not is_instance_valid(scene._strategic_node) or scene._strategic_node.name != "RTSSyriaOverview":
		_fail(7, "Geo overlay smoke: RTS macro terrain is missing at Z8")
		return
	if not (scene._strategic_node.material_override is ShaderMaterial):
		_fail(8, "Geo overlay smoke: RTS macro does not use macro shader material")
		return
	var shader_path: String = String(scene._strategic_node.material_override.shader.resource_path)
	if not shader_path.ends_with("StrategicMacro.gdshader"):
		_fail(9, "Geo overlay smoke: tactical noise shader leaked into RTS overview")
		return
	if scene._geo_overlay_boundary_count < 1 or scene._geo_overlay_label_count < 1:
		_fail(10, "Geo overlay smoke: boundaries or labels did not render at Z8")
		return

	var checked_world_space_label := false
	for child in scene._geo_overlay_root.get_children():
		if child is Label3D:
			checked_world_space_label = true
			if child.fixed_size:
				_fail(14, "Geo overlay smoke: fixed-size Label3D regression")
				return
			if child.pixel_size <= 0.0:
				_fail(15, "Geo overlay smoke: invalid world-space label scale")
				return
	if not checked_world_space_label:
		_fail(16, "Geo overlay smoke: no geographic Label3D rendered")
		return

	if not _visible_world_fits(scene):
		_fail(11, "Geo overlay smoke: Z8 camera can see outside the terrain world")
		return

	scene._on_zoom_wheel_changed(7.0)
	await process_frame
	if not _visible_world_fits(scene):
		_fail(12, "Geo overlay smoke: Z7 camera can see outside the terrain world")
		return

	scene._on_mode_pressed()
	await process_frame
	if scene._geo_overlay_root.visible:
		_fail(13, "Geo overlay smoke: battlefield overlay remains visible in map view")
		return

	print("Geo overlay smoke: RTS macro LOD + camera bounds + boundaries/names OK")
	quit(0)
