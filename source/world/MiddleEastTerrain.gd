extends Node3D

# DAM real-Earth terrain foundation.
# Geometry is generated from real DEM elevation tiles and placed on a WGS84
# ellipsoid. One Godot world unit equals one kilometer.

const MIN_ZOOM := 4
const MAX_ZOOM := 10
const DEFAULT_ZOOM := 5
const TILE_RADIUS := 1
const MAX_PARALLEL_REQUESTS := 5
const TERRARIUM_URL := "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png"
const CACHE_ROOT := "user://dam_terrain_cache/terrarium"

# Prototype Middle East streaming bounds. These are loading bounds, not political borders.
const REGION_WEST := 24.0
const REGION_EAST := 64.5
const REGION_NORTH := 43.0
const REGION_SOUTH := 11.5

# WGS84 ellipsoid, in kilometers.
const WGS84_A := 6378.137
const WGS84_F := 1.0 / 298.257223563
const WGS84_E2 := WGS84_F * (2.0 - WGS84_F)

@onready var terrain_root: Node3D = $TerrainRoot
@onready var camera: Camera3D = $Camera3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var zoom_label: Label = $HUD/TopBar/ZoomLabel
@onready var status_label: Label = $HUD/TopBar/StatusLabel

var _zoom := DEFAULT_ZOOM
var _center_lon := 44.25
var _center_lat := 27.25

var _tiles := {}
var _required_keys := {}
var _pending: Array = []
var _queued := {}
var _inflight := {}
var _active_requests := 0
var _failed_requests := 0

var _touches := {}
var _pinch_accumulator := 0.0
var _mouse_dragging := false
var _terrain_material: StandardMaterial3D


func _ready() -> void:
	_setup_environment()
	_setup_material()
	_position_camera()
	_refresh_tiles()
	_update_status()


func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.36, 0.67, 0.86, 1.0)
	environment.background_energy_multiplier = 0.8
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.68, 0.72, 0.76, 1.0)
	environment.ambient_light_energy = 0.9
	world_environment.environment = environment


func _setup_material() -> void:
	_terrain_material = StandardMaterial3D.new()
	_terrain_material.vertex_color_use_as_albedo = true
	_terrain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_terrain_material.roughness = 1.0
	_terrain_material.metallic = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_accumulator = 0.0
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		if not _touches.has(event.index):
			_touches[event.index] = event.position - event.relative

		if _touches.size() == 1:
			_touches[event.index] = event.position
			_pan_from_screen_delta(event.relative)
		else:
			var ids := _touches.keys()
			var first_id = ids[0]
			var second_id = ids[1]
			var old_a: Vector2 = _touches[first_id]
			var old_b: Vector2 = _touches[second_id]
			var old_distance := old_a.distance_to(old_b)
			_touches[event.index] = event.position
			var new_a: Vector2 = _touches[first_id]
			var new_b: Vector2 = _touches[second_id]
			var new_distance := new_a.distance_to(new_b)
			_pinch_accumulator += new_distance - old_distance
			if abs(_pinch_accumulator) >= 45.0:
				_set_zoom(_zoom + (1 if _pinch_accumulator > 0.0 else -1))
				_pinch_accumulator = 0.0

		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom + 1)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom - 1)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _mouse_dragging:
		_pan_from_screen_delta(event.relative)
		get_viewport().set_input_as_handled()


func _pan_from_screen_delta(delta: Vector2) -> void:
	var circumference_at_lat := TAU * WGS84_A * maxf(0.15, cos(deg_to_rad(_center_lat)))
	var km_per_pixel := circumference_at_lat / (pow(2.0, float(_zoom)) * 256.0)

	var east_km := -delta.x * km_per_pixel
	var north_km := delta.y * km_per_pixel

	var lat_delta := rad_to_deg(north_km / WGS84_A)
	var lon_radius := WGS84_A * maxf(0.15, cos(deg_to_rad(_center_lat)))
	var lon_delta := rad_to_deg(east_km / lon_radius)

	_center_lat = clampf(_center_lat + lat_delta, REGION_SOUTH, REGION_NORTH)
	_center_lon = clampf(_center_lon + lon_delta, REGION_WEST, REGION_EAST)

	_position_camera()
	_refresh_tiles()


func _set_zoom(new_zoom: int) -> void:
	new_zoom = clampi(new_zoom, MIN_ZOOM, MAX_ZOOM)
	if new_zoom == _zoom:
		return
	_zoom = new_zoom
	_clear_visible_tiles()
	_position_camera()
	_refresh_tiles()
	_update_status()


func _position_camera() -> void:
	var surface := _geo_to_world(_center_lon, _center_lat, 0.0)
	var up := _surface_up(_center_lon, _center_lat)
	var north := _surface_north(_center_lon, _center_lat)
	var altitude := 4200.0 / pow(2.0, float(_zoom - MIN_ZOOM))
	camera.position = surface + up * altitude - north * (altitude * 0.52)
	camera.look_at(surface, up)
	camera.near = 0.05
	camera.far = 20000.0
	camera.fov = 54.0


func _refresh_tiles() -> void:
	var center_tile := _lon_lat_to_tile(_center_lon, _center_lat, _zoom)
	var max_index := int(pow(2.0, float(_zoom))) - 1
	var required := {}
	var candidates: Array = []

	for ty in range(center_tile.y - TILE_RADIUS, center_tile.y + TILE_RADIUS + 1):
		if ty < 0 or ty > max_index:
			continue
		for tx in range(center_tile.x - TILE_RADIUS, center_tile.x + TILE_RADIUS + 1):
			if tx < 0 or tx > max_index:
				continue
			if not _tile_intersects_region(_zoom, tx, ty):
				continue
			var key := _tile_key(_zoom, tx, ty)
			required[key] = true
			candidates.append({"z": _zoom, "x": tx, "y": ty, "key": key})

	# Publish the required set before any tile is queued. This prevents freshly
	# queued requests from being discarded as "not required".
	_required_keys = required

	for item in candidates:
		var key: String = item["key"]
		if not _tiles.has(key):
			_begin_tile(item["z"], item["x"], item["y"], key)

	for key in _tiles.keys().duplicate():
		if not required.has(key):
			var state: Dictionary = _tiles[key]
			var node: MeshInstance3D = state.get("node")
			if is_instance_valid(node):
				node.queue_free()
			_tiles.erase(key)

	_pump_requests()
	_update_status()

func _begin_tile(z: int, x: int, y: int, key: String) -> void:
	_tiles[key] = {
		"z": z,
		"x": x,
		"y": y,
		"node": null,
	}

	var cache_path := _cache_path(z, x, y)
	if FileAccess.file_exists(cache_path):
		var bytes := _read_bytes(cache_path)
		if not bytes.is_empty() and _build_tile_from_bytes(key, bytes):
			return

	_queue_request(z, x, y, key, cache_path)


func _queue_request(z: int, x: int, y: int, key: String, cache_path: String) -> void:
	if _queued.has(key) or _inflight.has(key):
		return
	_queued[key] = true
	_pending.append({
		"z": z,
		"x": x,
		"y": y,
		"key": key,
		"cache_path": cache_path,
	})


func _pump_requests() -> void:
	while _active_requests < MAX_PARALLEL_REQUESTS and not _pending.is_empty():
		var item: Dictionary = _pending.pop_front()
		var key: String = item["key"]
		_queued.erase(key)

		if not _required_keys.has(key):
			continue

		var request := HTTPRequest.new()
		request.use_threads = true
		request.timeout = 20.0
		add_child(request)

		_active_requests += 1
		_inflight[key] = true
		request.request_completed.connect(
			_on_request_completed.bind(request, item),
			CONNECT_ONE_SHOT
		)

		var url := TERRARIUM_URL % [item["z"], item["x"], item["y"]]
		var error := request.request(url)
		if error != OK:
			_active_requests -= 1
			_inflight.erase(key)
			_failed_requests += 1
			request.queue_free()


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	request: HTTPRequest,
	item: Dictionary
) -> void:
	_active_requests = maxi(0, _active_requests - 1)
	var key: String = item["key"]
	_inflight.erase(key)

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		_write_bytes(item["cache_path"], body)
		if _required_keys.has(key):
			if not _build_tile_from_bytes(key, body):
				_failed_requests += 1
	else:
		_failed_requests += 1

	if is_instance_valid(request):
		request.queue_free()

	_pump_requests()
	_update_status()


func _build_tile_from_bytes(key: String, bytes: PackedByteArray) -> bool:
	if not _tiles.has(key):
		return false

	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return false
	image.convert(Image.FORMAT_RGB8)

	var state: Dictionary = _tiles[key]
	var z: int = state["z"]
	var x: int = state["x"]
	var y: int = state["y"]
	var segments := _segments_for_zoom(z)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for gy in range(segments + 1):
		var v := float(gy) / float(segments)
		for gx in range(segments + 1):
			var u := float(gx) / float(segments)
			var px := clampi(int(round(u * float(image.get_width() - 1))), 0, image.get_width() - 1)
			var py := clampi(int(round(v * float(image.get_height() - 1))), 0, image.get_height() - 1)
			var color := image.get_pixel(px, py)
			var elevation_m := _decode_terrarium(color)
			var geo := _tile_fraction_to_lon_lat(z, x, y, u, v)
			var position := _geo_to_world(geo.x, geo.y, elevation_m / 1000.0)
			surface.set_color(_height_color(elevation_m))
			surface.add_vertex(position)

	var row := segments + 1
	for gy in range(segments):
		for gx in range(segments):
			var i0 := gy * row + gx
			var i1 := i0 + 1
			var i2 := i0 + row
			var i3 := i2 + 1

			surface.add_index(i0)
			surface.add_index(i2)
			surface.add_index(i1)

			surface.add_index(i1)
			surface.add_index(i2)
			surface.add_index(i3)

	surface.generate_normals()
	var mesh := surface.commit()
	if mesh == null:
		return false

	var node := MeshInstance3D.new()
	node.name = "Terrain_%d_%d_%d" % [z, x, y]
	node.mesh = mesh
	node.material_override = _terrain_material
	terrain_root.add_child(node)

	var old_node: MeshInstance3D = state.get("node")
	if is_instance_valid(old_node):
		old_node.queue_free()
	state["node"] = node
	_tiles[key] = state
	return true


func _segments_for_zoom(z: int) -> int:
	return 32 if z <= 6 else 64


func _decode_terrarium(color: Color) -> float:
	var red := int(round(color.r * 255.0))
	var green := int(round(color.g * 255.0))
	var blue := int(round(color.b * 255.0))
	return float(red * 256 + green) + float(blue) / 256.0 - 32768.0


func _height_color(elevation_m: float) -> Color:
	if elevation_m <= 0.0:
		return Color(0.08, 0.31, 0.50, 1.0)
	if elevation_m < 250.0:
		return Color(0.56, 0.48, 0.31, 1.0)
	if elevation_m < 900.0:
		return Color(0.48, 0.40, 0.26, 1.0)
	if elevation_m < 1800.0:
		return Color(0.39, 0.33, 0.25, 1.0)
	if elevation_m < 3000.0:
		return Color(0.45, 0.43, 0.39, 1.0)
	return Color(0.78, 0.78, 0.76, 1.0)


func _geo_to_world(lon_deg: float, lat_deg: float, height_km: float) -> Vector3:
	var lon := deg_to_rad(lon_deg)
	var lat := deg_to_rad(lat_deg)
	var sin_lat := sin(lat)
	var cos_lat := cos(lat)
	var radius := WGS84_A / sqrt(1.0 - WGS84_E2 * sin_lat * sin_lat)

	var ecef_x := (radius + height_km) * cos_lat * cos(lon)
	var ecef_y := (radius + height_km) * cos_lat * sin(lon)
	var ecef_z := (radius * (1.0 - WGS84_E2) + height_km) * sin_lat

	# Map ECEF to Godot coordinates with +Y as north-axis vertical.
	return Vector3(ecef_x, ecef_z, -ecef_y)


func _surface_up(lon_deg: float, lat_deg: float) -> Vector3:
	var lon := deg_to_rad(lon_deg)
	var lat := deg_to_rad(lat_deg)
	return Vector3(
		cos(lat) * cos(lon),
		sin(lat),
		-cos(lat) * sin(lon)
	).normalized()


func _surface_north(lon_deg: float, lat_deg: float) -> Vector3:
	var lon := deg_to_rad(lon_deg)
	var lat := deg_to_rad(lat_deg)
	return Vector3(
		-sin(lat) * cos(lon),
		cos(lat),
		sin(lat) * sin(lon)
	).normalized()


func _lon_lat_to_tile(lon: float, lat: float, z: int) -> Vector2i:
	var n := pow(2.0, float(z))
	var safe_lat := clampf(lat, -85.05112878, 85.05112878)
	var x := int(floor((lon + 180.0) / 360.0 * n))
	var lat_rad := deg_to_rad(safe_lat)
	var y := int(floor((1.0 - asinh(tan(lat_rad)) / PI) * 0.5 * n))
	return Vector2i(x, y)


func _tile_fraction_to_lon_lat(z: int, x: int, y: int, u: float, v: float) -> Vector2:
	var n := pow(2.0, float(z))
	var xf := float(x) + u
	var yf := float(y) + v
	var lon := xf / n * 360.0 - 180.0
	var mercator := PI * (1.0 - 2.0 * yf / n)
	var lat := rad_to_deg(atan(sinh(mercator)))
	return Vector2(lon, lat)


func _tile_intersects_region(z: int, x: int, y: int) -> bool:
	var north_west := _tile_fraction_to_lon_lat(z, x, y, 0.0, 0.0)
	var south_east := _tile_fraction_to_lon_lat(z, x, y, 1.0, 1.0)
	return (
		south_east.x >= REGION_WEST
		and north_west.x <= REGION_EAST
		and south_east.y <= REGION_NORTH
		and north_west.y >= REGION_SOUTH
	)


func _tile_key(z: int, x: int, y: int) -> String:
	return "%d/%d/%d" % [z, x, y]


func _cache_path(z: int, x: int, y: int) -> String:
	return "%s/%d/%d/%d.png" % [CACHE_ROOT, z, x, y]


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()


func _clear_visible_tiles() -> void:
	for state in _tiles.values():
		var node: MeshInstance3D = state.get("node")
		if is_instance_valid(node):
			node.queue_free()
	_tiles.clear()
	_required_keys.clear()
	_pending.clear()
	_queued.clear()


func _update_status() -> void:
	zoom_label.text = "ZOOM %d / %d" % [_zoom, MAX_ZOOM]
	var loading := _active_requests + _pending.size()
	if loading > 0:
		status_label.text = "LOADING REAL TERRAIN • %d" % loading
	elif _failed_requests > 0:
		status_label.text = "TERRAIN READY • %d TILE ERRORS" % _failed_requests
	else:
		status_label.text = "REAL TERRAIN READY"


func _on_zoom_in_pressed() -> void:
	_set_zoom(_zoom + 1)


func _on_zoom_out_pressed() -> void:
	_set_zoom(_zoom - 1)


func _on_reset_pressed() -> void:
	_center_lon = 44.25
	_center_lat = 27.25
	_set_zoom(DEFAULT_ZOOM)
	_position_camera()
	_refresh_tiles()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
