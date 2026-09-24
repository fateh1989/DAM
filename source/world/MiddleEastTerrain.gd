extends Node3D

# DAM real-map foundation.
# The player sees a continuous map surface. Raster map tiles are only an
# internal streaming source; real elevation is applied from DEM data.
# One Godot world unit equals one kilometer.

const MIN_ZOOM := 4
const MAX_ZOOM := 10
const DEFAULT_ZOOM := 5
const TILE_RADIUS := 2
const MAX_PARALLEL_REQUESTS := 4

const MAP_TILE_URL := "https://tile.openstreetmap.org/%d/%d/%d.png"
const DEM_TILE_URL := "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png"
const MAP_CACHE_ROOT := "user://dam_map_cache/osm"
const DEM_CACHE_ROOT := "user://dam_map_cache/terrarium"
const MAP_CACHE_MAX_AGE_SEC := 604800

# Loading bounds only. They are not political borders.
const REGION_WEST := 24.0
const REGION_EAST := 64.5
const REGION_NORTH := 43.0
const REGION_SOUTH := 11.5

# WGS84 ellipsoid, kilometers.
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
var _failed_map := 0
var _failed_dem := 0

var _touches := {}
var _pinch_accumulator := 0.0
var _mouse_dragging := false


func _ready() -> void:
	_setup_environment()
	_position_camera()
	_refresh_tiles()
	_update_status()


func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.15, 0.38, 0.58, 1.0)
	environment.background_energy_multiplier = 0.8
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.82, 0.84, 0.86, 1.0)
	environment.ambient_light_energy = 1.0
	world_environment.environment = environment


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
			if abs(_pinch_accumulator) >= 42.0:
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

	# Mostly top-down like a map application, while retaining visible 3D terrain.
	var altitude := 4300.0 / pow(2.0, float(_zoom - MIN_ZOOM))
	camera.position = surface + up * altitude - north * (altitude * 0.22)
	camera.look_at(surface, up)
	camera.near = 0.05
	camera.far = 20000.0
	camera.fov = 48.0


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

	_required_keys = required

	for item in candidates:
		var key: String = item["key"]
		if not _tiles.has(key):
			_begin_tile(item["z"], item["x"], item["y"], key)

	for key in _tiles.keys().duplicate():
		if not required.has(key):
			_remove_tile(key)

	_pump_requests()
	_update_status()


func _begin_tile(z: int, x: int, y: int, key: String) -> void:
	_tiles[key] = {
		"z": z,
		"x": x,
		"y": y,
		"node": null,
		"dem_image": null,
		"map_texture": null,
	}

	var map_cache := _map_cache_path(z, x, y)
	var dem_cache := _dem_cache_path(z, x, y)

	var map_loaded := false
	if _cache_is_fresh(map_cache, MAP_CACHE_MAX_AGE_SEC):
		var map_bytes := _read_bytes(map_cache)
		map_loaded = not map_bytes.is_empty() and _apply_map_bytes(key, map_bytes)

	var dem_loaded := false
	if FileAccess.file_exists(dem_cache):
		var dem_bytes := _read_bytes(dem_cache)
		dem_loaded = not dem_bytes.is_empty() and _apply_dem_bytes(key, dem_bytes)

	# Interleave map and elevation work so visible map content appears quickly.
	if not map_loaded:
		_queue_request("map", z, x, y, key, map_cache)
	if not dem_loaded:
		_queue_request("dem", z, x, y, key, dem_cache)

	# If cached elevation exists but no map texture yet, keep a neutral terrain
	# placeholder instead of a blue/blank screen.
	if dem_loaded and not map_loaded:
		_rebuild_tile(key)


func _queue_request(kind: String, z: int, x: int, y: int, key: String, cache_path: String) -> void:
	var request_key := "%s:%s" % [kind, key]
	if _queued.has(request_key) or _inflight.has(request_key):
		return

	var url := MAP_TILE_URL % [z, x, y] if kind == "map" else DEM_TILE_URL % [z, x, y]
	_queued[request_key] = true
	_pending.append({
		"kind": kind,
		"z": z,
		"x": x,
		"y": y,
		"key": key,
		"request_key": request_key,
		"cache_path": cache_path,
		"url": url,
	})


func _pump_requests() -> void:
	while _active_requests < MAX_PARALLEL_REQUESTS and not _pending.is_empty():
		var item: Dictionary = _pending.pop_front()
		var request_key: String = item["request_key"]
		var key: String = item["key"]
		_queued.erase(request_key)

		if not _required_keys.has(key):
			continue

		var request := HTTPRequest.new()
		request.use_threads = true
		request.timeout = 20.0
		add_child(request)

		_active_requests += 1
		_inflight[request_key] = true
		request.request_completed.connect(
			_on_request_completed.bind(request, item),
			CONNECT_ONE_SHOT
		)

		var headers := PackedStringArray([
			"User-Agent: DAM-RTS/0.1 (github.com/fateh1989/DAM)",
			"Accept: image/png,image/*"
		])
		var error := request.request(item["url"], headers)
		if error != OK:
			_active_requests -= 1
			_inflight.erase(request_key)
			_note_failure(item["kind"])
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
	var request_key: String = item["request_key"]
	var key: String = item["key"]
	_inflight.erase(request_key)

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and not body.is_empty():
		_write_bytes(item["cache_path"], body)
		if _required_keys.has(key):
			var ok := _apply_map_bytes(key, body) if item["kind"] == "map" else _apply_dem_bytes(key, body)
			if not ok:
				_note_failure(item["kind"])
	else:
		_note_failure(item["kind"])

	if is_instance_valid(request):
		request.queue_free()

	_pump_requests()
	_update_status()


func _apply_map_bytes(key: String, bytes: PackedByteArray) -> bool:
	if not _tiles.has(key):
		return false

	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return false

	var texture := ImageTexture.create_from_image(image)
	var state: Dictionary = _tiles[key]
	state["map_texture"] = texture
	_tiles[key] = state

	var node: MeshInstance3D = state.get("node")
	if is_instance_valid(node):
		node.material_override = _make_tile_material(texture)
	else:
		# Build a flat, textured geographic tile immediately. When DEM arrives,
		# the same tile is rebuilt with its real elevation.
		_rebuild_tile(key)
	return true


func _apply_dem_bytes(key: String, bytes: PackedByteArray) -> bool:
	if not _tiles.has(key):
		return false

	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return false
	image.convert(Image.FORMAT_RGB8)

	var state: Dictionary = _tiles[key]
	state["dem_image"] = image
	_tiles[key] = state
	_rebuild_tile(key)
	return true


func _rebuild_tile(key: String) -> void:
	if not _tiles.has(key):
		return

	var state: Dictionary = _tiles[key]
	var z: int = state["z"]
	var x: int = state["x"]
	var y: int = state["y"]
	var dem_image: Image = state.get("dem_image")
	var map_texture: Texture2D = state.get("map_texture")

	var segments := _segments_for_zoom(z)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for gy in range(segments + 1):
		var v := float(gy) / float(segments)
		for gx in range(segments + 1):
			var u := float(gx) / float(segments)
			var elevation_m := 0.0

			if dem_image != null:
				var px := clampi(int(round(u * float(dem_image.get_width() - 1))), 0, dem_image.get_width() - 1)
				var py := clampi(int(round(v * float(dem_image.get_height() - 1))), 0, dem_image.get_height() - 1)
				elevation_m = _decode_terrarium(dem_image.get_pixel(px, py))

			var geo := _tile_fraction_to_lon_lat(z, x, y, u, v)
			var position := _geo_to_world(geo.x, geo.y, elevation_m / 1000.0)

			surface.set_uv(Vector2(u, v))
			surface.set_color(Color.WHITE)
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
		return

	var node: MeshInstance3D = state.get("node")
	if not is_instance_valid(node):
		node = MeshInstance3D.new()
		node.name = "MapTerrain_%d_%d_%d" % [z, x, y]
		terrain_root.add_child(node)

	node.mesh = mesh
	node.material_override = _make_tile_material(map_texture)

	state["node"] = node
	_tiles[key] = state


func _make_tile_material(map_texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = false
	material.roughness = 1.0
	material.metallic = 0.0

	if map_texture != null:
		material.albedo_texture = map_texture
		material.albedo_color = Color.WHITE
	else:
		material.albedo_color = Color(0.58, 0.58, 0.55, 1.0)

	return material


func _segments_for_zoom(z: int) -> int:
	if z <= 5:
		return 48
	if z <= 7:
		return 64
	return 80


func _decode_terrarium(color: Color) -> float:
	var red := int(round(color.r * 255.0))
	var green := int(round(color.g * 255.0))
	var blue := int(round(color.b * 255.0))
	return float(red * 256 + green) + float(blue) / 256.0 - 32768.0


func _geo_to_world(lon_deg: float, lat_deg: float, height_km: float) -> Vector3:
	var lon := deg_to_rad(lon_deg)
	var lat := deg_to_rad(lat_deg)
	var sin_lat := sin(lat)
	var cos_lat := cos(lat)
	var radius := WGS84_A / sqrt(1.0 - WGS84_E2 * sin_lat * sin_lat)

	var ecef_x := (radius + height_km) * cos_lat * cos(lon)
	var ecef_y := (radius + height_km) * cos_lat * sin(lon)
	var ecef_z := (radius * (1.0 - WGS84_E2) + height_km) * sin_lat

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


func _map_cache_path(z: int, x: int, y: int) -> String:
	return "%s/%d/%d/%d.png" % [MAP_CACHE_ROOT, z, x, y]


func _dem_cache_path(z: int, x: int, y: int) -> String:
	return "%s/%d/%d/%d.png" % [DEM_CACHE_ROOT, z, x, y]


func _cache_is_fresh(path: String, max_age_seconds: int) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var modified := FileAccess.get_modified_time(path)
	if modified <= 0:
		return false

	var now := int(Time.get_unix_time_from_system())
	return now - int(modified) <= max_age_seconds


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


func _remove_tile(key: String) -> void:
	if not _tiles.has(key):
		return
	var state: Dictionary = _tiles[key]
	var node: MeshInstance3D = state.get("node")
	if is_instance_valid(node):
		node.queue_free()
	_tiles.erase(key)


func _clear_visible_tiles() -> void:
	for key in _tiles.keys().duplicate():
		_remove_tile(key)
	_required_keys.clear()
	_pending.clear()
	_queued.clear()


func _note_failure(kind: String) -> void:
	if kind == "map":
		_failed_map += 1
	else:
		_failed_dem += 1


func _update_status() -> void:
	zoom_label.text = "ZOOM %d / %d" % [_zoom, MAX_ZOOM]
	var loading := _active_requests + _pending.size()

	if loading > 0:
		status_label.text = "LOADING MAP • %d" % loading
	elif _failed_map > 0 or _failed_dem > 0:
		status_label.text = "MAP READY • M%d E%d" % [_failed_map, _failed_dem]
	else:
		status_label.text = "REAL MAP READY"


func _on_zoom_in_pressed() -> void:
	_set_zoom(_zoom + 1)


func _on_zoom_out_pressed() -> void:
	_set_zoom(_zoom - 1)


func _on_reset_pressed() -> void:
	_center_lon = 44.25
	_center_lat = 27.25
	if _zoom != DEFAULT_ZOOM:
		_set_zoom(DEFAULT_ZOOM)
	else:
		_clear_visible_tiles()
		_position_camera()
		_refresh_tiles()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
