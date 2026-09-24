extends Node3D

# DAM real-world strategy terrain prototype.
#
# Design rule:
# - MAP mode behaves like a map application.
# - TERRAIN mode behaves like a classic isometric RTS battlefield.
# - Both are generated from the SAME real geographic coordinates.
# - OSM raster tiles are only a temporary visual reference.
# - Terrarium DEM supplies the real elevation shape.
#
# Red Alert 2 used a tile grid with explicit height levels, ramps and cliffs.
# DAM mirrors that idea by quantizing real DEM elevations into readable RTS
# levels, while keeping the horizontal geography tied to real WGS84 positions.

const MIN_ZOOM := 4
const MAP_MAX_ZOOM := 10
const MAX_ZOOM := 14
const DEFAULT_ZOOM := 5
const TERRAIN_DEFAULT_ZOOM := 11

const TILE_RADIUS := 2
const KEEP_TILE_RADIUS := 4
const MAX_PARALLEL_REQUESTS := 4

const MAP_TILE_URL := "https://tile.openstreetmap.org/%d/%d/%d.png"
const DEM_TILE_URL := "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png"
const MAP_CACHE_ROOT := "user://dam_map_cache/osm"
const DEM_CACHE_ROOT := "user://dam_map_cache/terrarium"
const MAP_CACHE_MAX_AGE_SEC := 604800

# Loading bounds only; not political borders.
const REGION_WEST := 24.0
const REGION_EAST := 64.5
const REGION_NORTH := 43.0
const REGION_SOUTH := 11.5

# Local geographic rendering origin. Horizontal distances remain metric-ish
# kilometers around the Middle East instead of drawing a curved globe patch.
const ORIGIN_LON := 44.25
const ORIGIN_LAT := 27.25
const EARTH_RADIUS_KM := 6371.0088

# RTS terrain rendering. Horizontal geography comes from real coordinates.
# Height is deliberately quantized/exaggerated for battlefield readability,
# like classic isometric RTS height levels.
const RTS_LEVEL_METERS := 50.0
const RTS_VERTICAL_EXAGGERATION := 2.6

@onready var terrain_root: Node3D = $TerrainRoot
@onready var camera: Camera3D = $Camera3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var zoom_label: Label = $HUD/TopBar/ZoomLabel
@onready var status_label: Label = $HUD/TopBar/StatusLabel
@onready var mode_button: Button = $HUD/ModeButton

var _zoom := DEFAULT_ZOOM
var _map_zoom := DEFAULT_ZOOM
var _center_lon := ORIGIN_LON
var _center_lat := ORIGIN_LAT
var _terrain_mode := false

var _tiles := {}
var _required_keys := {}
var _keep_keys := {}
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
	environment.background_color = Color(0.12, 0.30, 0.46, 1.0)
	environment.background_energy_multiplier = 0.8
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.80, 1.0)
	environment.ambient_light_energy = 0.72
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
	var viewport_height := maxf(1.0, float(get_viewport().get_visible_rect().size.y))
	var km_per_pixel := 0.0

	if _terrain_mode:
		km_per_pixel = _approx_tile_width_km() / 210.0
	else:
		km_per_pixel = camera.size / viewport_height

	var east_km := -delta.x * km_per_pixel
	var north_km := delta.y * km_per_pixel

	var lat_delta := rad_to_deg(north_km / EARTH_RADIUS_KM)
	var lon_radius := EARTH_RADIUS_KM * maxf(0.15, cos(deg_to_rad(_center_lat)))
	var lon_delta := rad_to_deg(east_km / lon_radius)

	_center_lat = clampf(_center_lat + lat_delta, REGION_SOUTH, REGION_NORTH)
	_center_lon = clampf(_center_lon + lon_delta, REGION_WEST, REGION_EAST)

	_position_camera()
	_refresh_tiles()


func _set_zoom(new_zoom: int) -> void:
	var max_zoom := MAX_ZOOM if _terrain_mode else MAP_MAX_ZOOM
	new_zoom = clampi(new_zoom, MIN_ZOOM, max_zoom)
	if new_zoom == _zoom:
		return

	_zoom = new_zoom
	if not _terrain_mode:
		_map_zoom = _zoom

	_clear_visible_tiles()
	_position_camera()
	_refresh_tiles()
	_update_status()


func _position_camera() -> void:
	var center := _geo_to_local(_center_lon, _center_lat, 0.0)
	var tile_km := _approx_tile_width_km()

	if _terrain_mode:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		var altitude := maxf(8.0, tile_km * 2.15)
		camera.position = center + Vector3(0.0, altitude, altitude * 0.82)
		camera.look_at(center, Vector3.UP)
		camera.fov = 46.0
		camera.near = 0.02
		camera.far = 5000.0
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = tile_km * 4.55
		camera.position = center + Vector3(0.0, 500.0, 0.01)
		camera.look_at(center, Vector3(0.0, 0.0, -1.0))
		camera.near = 0.1
		camera.far = 1000.0


func _refresh_tiles() -> void:
	var center_tile := _lon_lat_to_tile(_center_lon, _center_lat, _zoom)
	var max_index := int(pow(2.0, float(_zoom))) - 1
	var required := {}
	var keep := {}
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

	for ty in range(center_tile.y - KEEP_TILE_RADIUS, center_tile.y + KEEP_TILE_RADIUS + 1):
		if ty < 0 or ty > max_index:
			continue
		for tx in range(center_tile.x - KEEP_TILE_RADIUS, center_tile.x + KEEP_TILE_RADIUS + 1):
			if tx < 0 or tx > max_index:
				continue
			if not _tile_intersects_region(_zoom, tx, ty):
				continue
			keep[_tile_key(_zoom, tx, ty)] = true

	_required_keys = required
	_keep_keys = keep

	for item in candidates:
		var key: String = item["key"]
		if not _tiles.has(key):
			_begin_tile(item["z"], item["x"], item["y"], key)

	for key in _tiles.keys().duplicate():
		if not keep.has(key):
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
		"map_image": null,
		"map_texture": null,
		"terrain_texture": null,
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

	# Always prioritize the visible map image. Elevation follows behind it.
	if not map_loaded:
		_queue_request("map", z, x, y, key, map_cache)
	elif not dem_loaded:
		_queue_request("dem", z, x, y, key, dem_cache)


func _queue_request(kind: String, z: int, x: int, y: int, key: String, cache_path: String) -> void:
	var request_key := "%s:%s" % [kind, key]
	if _queued.has(request_key) or _inflight.has(request_key):
		return

	var url := MAP_TILE_URL % [z, x, y] if kind == "map" else DEM_TILE_URL % [z, x, y]
	var queue_item := {
		"kind": kind,
		"z": z,
		"x": x,
		"y": y,
		"key": key,
		"request_key": request_key,
		"cache_path": cache_path,
		"url": url,
	}

	_queued[request_key] = true
	if kind == "map":
		_pending.push_front(queue_item)
	else:
		_pending.append(queue_item)


func _pump_requests() -> void:
	while _active_requests < MAX_PARALLEL_REQUESTS and not _pending.is_empty():
		var item: Dictionary = _pending.pop_front()
		var request_key: String = item["request_key"]
		var key: String = item["key"]
		_queued.erase(request_key)

		if not _keep_keys.has(key):
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
		if _keep_keys.has(key):
			var ok := _apply_map_bytes(key, body) if item["kind"] == "map" else _apply_dem_bytes(key, body)
			if not ok:
				_note_failure(item["kind"])
			elif item["kind"] == "map":
				var state: Dictionary = _tiles.get(key, {})
				if state.get("dem_image") == null:
					_queue_request(
						"dem",
						item["z"],
						item["x"],
						item["y"],
						key,
						_dem_cache_path(item["z"], item["x"], item["y"])
					)
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
	image.convert(Image.FORMAT_RGBA8)

	var state: Dictionary = _tiles[key]
	state["map_image"] = image
	state["map_texture"] = ImageTexture.create_from_image(image)

	var dem_image: Image = state.get("dem_image")
	if dem_image != null:
		state["terrain_texture"] = _build_game_terrain_texture(image, dem_image, state["z"], state["y"])

	_tiles[key] = state
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

	var map_image: Image = state.get("map_image")
	if map_image != null:
		state["terrain_texture"] = _build_game_terrain_texture(map_image, image, state["z"], state["y"])

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
	var terrain_texture: Texture2D = state.get("terrain_texture")
	var visible_texture: Texture2D = terrain_texture if _terrain_mode and terrain_texture != null else map_texture

	var segments := _segments_for_zoom(z)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for gy in range(segments + 1):
		var v := float(gy) / float(segments)
		for gx in range(segments + 1):
			var u := float(gx) / float(segments)
			var elevation_m := 0.0

			if dem_image != null:
				elevation_m = _sample_dem(dem_image, u, v)

			var render_height_m := 0.0
			if _terrain_mode:
				render_height_m = _rts_height_m(elevation_m)

			var geo := _tile_fraction_to_lon_lat(z, x, y, u, v)
			var position := _geo_to_local(geo.x, geo.y, render_height_m / 1000.0)

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
		node.name = "WorldCell_%d_%d_%d" % [z, x, y]
		terrain_root.add_child(node)

	node.mesh = mesh
	node.material_override = _make_tile_material(visible_texture)

	state["node"] = node
	_tiles[key] = state


func _make_tile_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = false
	material.roughness = 1.0
	material.metallic = 0.0

	if not _terrain_mode:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if texture != null:
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
	else:
		material.albedo_color = Color(0.42, 0.39, 0.31, 1.0)

	return material


func _build_game_terrain_texture(map_image: Image, dem_image: Image, z: int, tile_y: int) -> Texture2D:
	# Blur away labels and tiny cartographic marks. What remains is a rough
	# real-world land/water/vegetation color reference, then DEM hillshade is
	# added on top to make it read like an RTS terrain tile instead of a map.
	var blurred := map_image.duplicate()
	blurred.resize(32, 32, Image.INTERPOLATE_BILINEAR)
	blurred.resize(128, 128, Image.INTERPOLATE_BILINEAR)
	blurred.convert(Image.FORMAT_RGBA8)

	var out := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var tile_center := _tile_fraction_to_lon_lat(z, 0, tile_y, 0.5, 0.5)
	var meters_per_pixel := (
		TAU * EARTH_RADIUS_KM * 1000.0 * maxf(0.15, cos(deg_to_rad(tile_center.y)))
		/ (pow(2.0, float(z)) * 128.0)
	)

	for py in range(128):
		var v := float(py) / 127.0
		for px in range(128):
			var u := float(px) / 127.0
			var base := blurred.get_pixel(px, py)
			var elevation := _sample_dem(dem_image, u, v)

			var du := 1.0 / 128.0
			var dv := 1.0 / 128.0
			var h_l := _sample_dem(dem_image, clampf(u - du, 0.0, 1.0), v)
			var h_r := _sample_dem(dem_image, clampf(u + du, 0.0, 1.0), v)
			var h_u := _sample_dem(dem_image, u, clampf(v - dv, 0.0, 1.0))
			var h_d := _sample_dem(dem_image, u, clampf(v + dv, 0.0, 1.0))

			var dx := (h_r - h_l) / maxf(1.0, meters_per_pixel * 2.0)
			var dy := (h_d - h_u) / maxf(1.0, meters_per_pixel * 2.0)
			var normal := Vector3(-dx * 2.2, -dy * 2.2, 1.0).normalized()
			var light := Vector3(-0.45, -0.50, 0.74).normalized()
			var shade := clampf(0.74 + normal.dot(light) * 0.34, 0.48, 1.10)

			var looks_like_water := (
				base.b > base.r * 1.07
				and base.b > base.g * 1.03
				and base.b > 0.55
			)

			var terrain_color := Color(0.56, 0.48, 0.33, 1.0)
			if looks_like_water:
				terrain_color = Color(0.12, 0.34, 0.52, 1.0)
			elif base.g > base.r * 1.025 and base.g > base.b * 0.92:
				terrain_color = Color(0.34, 0.42, 0.25, 1.0)
			elif elevation > 1700.0:
				terrain_color = Color(0.42, 0.40, 0.36, 1.0)
			elif elevation > 700.0:
				terrain_color = Color(0.49, 0.43, 0.32, 1.0)

			# Retain some broad real-world source coloration after the label blur.
			terrain_color = terrain_color.lerp(base, 0.24)
			terrain_color.r = clampf(terrain_color.r * shade, 0.0, 1.0)
			terrain_color.g = clampf(terrain_color.g * shade, 0.0, 1.0)
			terrain_color.b = clampf(terrain_color.b * shade, 0.0, 1.0)
			out.set_pixel(px, py, terrain_color)

	return ImageTexture.create_from_image(out)


func _sample_dem(image: Image, u: float, v: float) -> float:
	var px := clampi(int(round(u * float(image.get_width() - 1))), 0, image.get_width() - 1)
	var py := clampi(int(round(v * float(image.get_height() - 1))), 0, image.get_height() - 1)
	return _decode_terrarium(image.get_pixel(px, py))


func _rts_height_m(real_height_m: float) -> float:
	# Classic RTS maps use explicit height levels. DAM derives the level from
	# real elevation instead of an artist painting it by hand.
	var level := round(real_height_m / RTS_LEVEL_METERS)
	return level * RTS_LEVEL_METERS * RTS_VERTICAL_EXAGGERATION


func _segments_for_zoom(z: int) -> int:
	if z <= 8:
		return 24
	if z <= 10:
		return 32
	if z == 11:
		return 40
	if z == 12:
		return 48
	return 64


func _decode_terrarium(color: Color) -> float:
	var red := int(round(color.r * 255.0))
	var green := int(round(color.g * 255.0))
	var blue := int(round(color.b * 255.0))
	return float(red * 256 + green) + float(blue) / 256.0 - 32768.0


func _geo_to_local(lon_deg: float, lat_deg: float, height_km: float) -> Vector3:
	var mean_lat := deg_to_rad((lat_deg + ORIGIN_LAT) * 0.5)
	var east := EARTH_RADIUS_KM * deg_to_rad(lon_deg - ORIGIN_LON) * cos(mean_lat)
	var north := EARTH_RADIUS_KM * deg_to_rad(lat_deg - ORIGIN_LAT)
	return Vector3(east, height_km, -north)


func _approx_tile_width_km() -> float:
	return (
		TAU * EARTH_RADIUS_KM * maxf(0.15, cos(deg_to_rad(_center_lat)))
		/ pow(2.0, float(_zoom))
	)


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
	_keep_keys.clear()
	_pending.clear()
	_queued.clear()


func _note_failure(kind: String) -> void:
	if kind == "map":
		_failed_map += 1
	else:
		_failed_dem += 1


func _update_status() -> void:
	zoom_label.text = "ZOOM %d / %d" % [_zoom, MAX_ZOOM if _terrain_mode else MAP_MAX_ZOOM]
	var loading := _active_requests + _pending.size()
	var mode_text := "RTS TERRAIN" if _terrain_mode else "MAP"

	if loading > 0:
		status_label.text = "%s • LOADING %d" % [mode_text, loading]
	elif _failed_map > 0 or _failed_dem > 0:
		status_label.text = "%s • READY M%d E%d" % [mode_text, _failed_map, _failed_dem]
	else:
		status_label.text = "%s • READY" % mode_text


func _on_mode_pressed() -> void:
	if _terrain_mode:
		_terrain_mode = false
		mode_button.text = "TERRAIN"
		_zoom = mini(_map_zoom, MAP_MAX_ZOOM)
	else:
		_map_zoom = mini(_zoom, MAP_MAX_ZOOM)
		_terrain_mode = true
		mode_button.text = "MAP"
		_zoom = maxi(_zoom, TERRAIN_DEFAULT_ZOOM)

	_clear_visible_tiles()
	_position_camera()
	_refresh_tiles()
	_update_status()


func _on_zoom_in_pressed() -> void:
	_set_zoom(_zoom + 1)


func _on_zoom_out_pressed() -> void:
	_set_zoom(_zoom - 1)


func _on_reset_pressed() -> void:
	_center_lon = ORIGIN_LON
	_center_lat = ORIGIN_LAT
	_zoom = TERRAIN_DEFAULT_ZOOM if _terrain_mode else DEFAULT_ZOOM
	if not _terrain_mode:
		_map_zoom = _zoom
	_clear_visible_tiles()
	_position_camera()
	_refresh_tiles()
	_update_status()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
