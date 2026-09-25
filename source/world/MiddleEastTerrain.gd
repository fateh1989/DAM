extends Node3D

# DAM world prototype:
# MAP = strategic cartographic view.
# TERRAIN = playable Red-Alert-like isometric battlefield generated from
# real DEM + real OpenStreetMap vectors (roads, buildings, water, place names).
#
# Important: geographic data stays real. Only the visual vertical scale is
# exaggerated so terrain is readable in an RTS camera.

const MIN_MAP_ZOOM := 4
const MAX_MAP_ZOOM := 10
const DEFAULT_MAP_ZOOM := 9

const TERRAIN_ZOOM := 13
const TERRAIN_TILE_RADIUS := 1
const MAP_TILE_RADIUS := 2
const KEEP_EXTRA := 1
const MAX_PARALLEL_REQUESTS := 5

const MAP_TILE_URL := "https://tile.openstreetmap.org/%d/%d/%d.png"
const DEM_TILE_URL := "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png"
const GOVERNORATES := [
	{"slug":"damascus","name_ar":"دمشق","name_en":"Damascus","lat":33.5138,"lon":36.2765},
	{"slug":"rif_dimashq","name_ar":"ريف دمشق","name_en":"Rif Dimashq","lat":33.5723,"lon":36.4027},
	{"slug":"aleppo","name_ar":"حلب","name_en":"Aleppo","lat":36.201241,"lon":37.161173},
	{"slug":"homs","name_ar":"حمص","name_en":"Homs","lat":34.7324,"lon":36.7137},
	{"slug":"hama","name_ar":"حماة","name_en":"Hama","lat":35.1318,"lon":36.7578},
	{"slug":"latakia","name_ar":"اللاذقية","name_en":"Latakia","lat":35.5317,"lon":35.7901},
	{"slug":"tartus","name_ar":"طرطوس","name_en":"Tartus","lat":34.8959,"lon":35.8867},
	{"slug":"idlib","name_ar":"إدلب","name_en":"Idlib","lat":35.9306,"lon":36.6339},
	{"slug":"raqqa","name_ar":"الرقة","name_en":"Raqqa","lat":35.9594,"lon":39.0079},
	{"slug":"deir_ez_zor","name_ar":"دير الزور","name_en":"Deir ez-Zor","lat":35.3359,"lon":40.1408},
	{"slug":"hasakah","name_ar":"الحسكة","name_en":"Al-Hasakah","lat":36.5024,"lon":40.7477},
	{"slug":"daraa","name_ar":"درعا","name_en":"Daraa","lat":32.6189,"lon":36.1021},
	{"slug":"suwayda","name_ar":"السويداء","name_en":"As-Suwayda","lat":32.7089,"lon":36.5695},
	{"slug":"quneitra","name_ar":"القنيطرة","name_en":"Quneitra","lat":33.1259,"lon":35.8246},
]
const DEFAULT_GOVERNORATE_INDEX := 2

const MAP_CACHE_ROOT := "user://dam_map_cache/osm"
const DEM_CACHE_ROOT := "user://dam_map_cache/terrarium"
const MAP_CACHE_MAX_AGE_SEC := 604800

const REGION_WEST := 35.55
const REGION_EAST := 42.45
const REGION_NORTH := 37.35
const REGION_SOUTH := 32.25

const EARTH_RADIUS_KM := 6371.0088
const VERTICAL_EXAGGERATION := 2.2

# Red-Alert-style cell terrain experiment.
# A real DEM tile is compiled into a discrete cell grid before rendering.
const CELL_GRID := 48
const CELL_HEIGHT_STEP_M := 20.0
const CELL_MAX_CORNER_DELTA := 1
const CLIFF_MIN_LEVELS := 2
const MAX_FOREST_TREES := 700
const MAX_ORCHARD_TREES := 450

# Vector-detail query radius around current terrain camera.
const VECTOR_HALF_LAT := 0.055
const VECTOR_HALF_LON := 0.065
const VECTOR_REFRESH_DISTANCE_DEG := 0.025

@onready var terrain_root: Node3D = $TerrainRoot
@onready var vector_root: Node3D = $VectorRoot
@onready var vegetation_root: Node3D = $VegetationRoot
@onready var labels_root: Node3D = $LabelsRoot
@onready var camera: Camera3D = $Camera3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var zoom_label: Label = $HUD/TopBar/Row/ZoomLabel
@onready var status_label: Label = $HUD/TopBar/Row/StatusLabel
@onready var mode_button: Button = $HUD/ModeButton
@onready var governorate_label: Label = $HUD/GovernorateBar/Row/GovernorateLabel

var _terrain_mode := false
var _map_zoom := DEFAULT_MAP_ZOOM
var _governorate_index := DEFAULT_GOVERNORATE_INDEX
var _center_lon := float(GOVERNORATES[DEFAULT_GOVERNORATE_INDEX]["lon"])
var _center_lat := float(GOVERNORATES[DEFAULT_GOVERNORATE_INDEX]["lat"])

var _origin_lon := float(GOVERNORATES[DEFAULT_GOVERNORATE_INDEX]["lon"])
var _origin_lat := float(GOVERNORATES[DEFAULT_GOVERNORATE_INDEX]["lat"])

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

var _vector_inflight := false
var _vector_loaded := false
var _last_vector_center := Vector2(999.0, 999.0)

var _feature_count := 0
var _road_feature_count := 0
var _building_feature_count := 0
var _water_feature_count := 0
var _landcover_feature_count := 0
var _tree_instance_count := 0
var _cliff_face_count := 0
var _native_core: Object = null


func _ready() -> void:
	if ClassDB.class_exists("DAMNativeCore"):
		_native_core = ClassDB.instantiate("DAMNativeCore")
	_setup_environment()
	_origin_lon = _center_lon
	_origin_lat = _center_lat
	_update_governorate_ui()
	_position_camera()
	_refresh_tiles()
	_update_status()


func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.19, 0.28, 0.34, 1.0)
	environment.background_energy_multiplier = 0.72
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.70, 0.68, 0.58, 1.0)
	environment.ambient_light_energy = 0.58
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
				if not _terrain_mode:
					_set_map_zoom(_map_zoom + (1 if _pinch_accumulator > 0.0 else -1))
				_pinch_accumulator = 0.0

		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP and not _terrain_mode:
			_set_map_zoom(_map_zoom + 1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not _terrain_mode:
			_set_map_zoom(_map_zoom - 1)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _mouse_dragging:
		_pan_from_screen_delta(event.relative)
		get_viewport().set_input_as_handled()


func _pan_from_screen_delta(delta: Vector2) -> void:
	var viewport_height := maxf(1.0, float(get_viewport().get_visible_rect().size.y))
	var km_per_pixel := 0.0

	if _terrain_mode:
		km_per_pixel = 0.018
	else:
		km_per_pixel = camera.size / viewport_height

	var east_km := -delta.x * km_per_pixel
	var north_km := delta.y * km_per_pixel
	var lat_delta := rad_to_deg(north_km / EARTH_RADIUS_KM)
	var lon_radius := EARTH_RADIUS_KM * maxf(0.15, cos(deg_to_rad(_center_lat)))
	var lon_delta := rad_to_deg(east_km / lon_radius)

	_center_lat = clampf(_center_lat + lat_delta, REGION_SOUTH, REGION_NORTH)
	_center_lon = clampf(_center_lon + lon_delta, REGION_WEST, REGION_EAST)

	# Keep local coordinates numerically small as the camera travels.
	if _terrain_mode and Vector2(_origin_lon, _origin_lat).distance_to(Vector2(_center_lon, _center_lat)) > 0.18:
		_origin_lon = _center_lon
		_origin_lat = _center_lat
		_clear_all_world_nodes()

	_position_camera()
	_refresh_tiles()


func _set_map_zoom(new_zoom: int) -> void:
	new_zoom = clampi(new_zoom, MIN_MAP_ZOOM, MAX_MAP_ZOOM)
	if new_zoom == _map_zoom:
		return
	_map_zoom = new_zoom
	_clear_tiles()
	_position_camera()
	_refresh_tiles()
	_update_status()


func _position_camera() -> void:
	var center := _geo_to_local(_center_lon, _center_lat, 0.0)

	if _terrain_mode:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.position = center + Vector3(0.0, 6.1, 7.2)
		camera.look_at(center + Vector3(0.0, 0.12, 0.0), Vector3.UP)
		camera.fov = 40.0
		camera.near = 0.01
		camera.far = 1000.0
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = _map_tile_width_km() * 4.7
		camera.position = center + Vector3(0.0, 500.0, 0.01)
		camera.look_at(center, Vector3(0.0, 0.0, -1.0))
		camera.near = 0.1
		camera.far = 1000.0


func _refresh_tiles() -> void:
	var zoom := TERRAIN_ZOOM if _terrain_mode else _map_zoom
	var radius := TERRAIN_TILE_RADIUS if _terrain_mode else MAP_TILE_RADIUS
	var keep_radius := radius + KEEP_EXTRA
	var center_tile := _lon_lat_to_tile(_center_lon, _center_lat, zoom)
	var max_index := int(pow(2.0, float(zoom))) - 1
	var required := {}
	var keep := {}

	for ty in range(center_tile.y - radius, center_tile.y + radius + 1):
		if ty < 0 or ty > max_index:
			continue
		for tx in range(center_tile.x - radius, center_tile.x + radius + 1):
			if tx < 0 or tx > max_index:
				continue
			var key := _tile_key(zoom, tx, ty)
			required[key] = true
			if not _tiles.has(key):
				_begin_tile(zoom, tx, ty, key)

	for ty in range(center_tile.y - keep_radius, center_tile.y + keep_radius + 1):
		if ty < 0 or ty > max_index:
			continue
		for tx in range(center_tile.x - keep_radius, center_tile.x + keep_radius + 1):
			if tx < 0 or tx > max_index:
				continue
			keep[_tile_key(zoom, tx, ty)] = true

	_required_keys = required
	_keep_keys = keep

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
		"map_texture": null,
		"cell_levels": PackedInt32Array(),
	}

	# Always draw a placeholder immediately so terrain mode is never blank.
	_rebuild_tile(key)

	if _terrain_mode:
		var dem_cache := _dem_cache_path(z, x, y)
		if FileAccess.file_exists(dem_cache):
			var bytes := _read_bytes(dem_cache)
			if not bytes.is_empty() and _apply_dem_bytes(key, bytes):
				return
		_queue_request("dem", z, x, y, key, dem_cache)
	else:
		var map_cache := _map_cache_path(z, x, y)
		if _cache_is_fresh(map_cache, MAP_CACHE_MAX_AGE_SEC):
			var map_bytes := _read_bytes(map_cache)
			if not map_bytes.is_empty() and _apply_map_bytes(key, map_bytes):
				return
		_queue_request("map", z, x, y, key, map_cache)


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
	state["map_texture"] = ImageTexture.create_from_image(image)
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

	if not _terrain_mode:
		_build_map_quad(state, key, z, x, y, map_texture)
		return

	# Real DEM stays authoritative. We only quantize and art-direct its visual
	# presentation so the battlefield reads like a classic RTS.
	var levels := PackedInt32Array()
	levels.resize((CELL_GRID + 1) * (CELL_GRID + 1))

	for gy in range(CELL_GRID + 1):
		var v := float(gy) / float(CELL_GRID)
		for gx in range(CELL_GRID + 1):
			var u := float(gx) / float(CELL_GRID)
			var elevation_m := 0.0
			if dem_image != null:
				elevation_m = _sample_dem(dem_image, u, v)
			levels[gy * (CELL_GRID + 1) + gx] = int(round(elevation_m / CELL_HEIGHT_STEP_M))

	for gy in range(CELL_GRID):
		for gx in range(CELL_GRID):
			var i00 := gy * (CELL_GRID + 1) + gx
			var i10 := i00 + 1
			var i01 := i00 + CELL_GRID + 1
			var i11 := i01 + 1
			var avg := int(round((
				float(levels[i00]) + float(levels[i10])
				+ float(levels[i01]) + float(levels[i11])
			) * 0.25))
			levels[i00] = clampi(levels[i00], avg - CELL_MAX_CORNER_DELTA, avg + CELL_MAX_CORNER_DELTA)
			levels[i10] = clampi(levels[i10], avg - CELL_MAX_CORNER_DELTA, avg + CELL_MAX_CORNER_DELTA)
			levels[i01] = clampi(levels[i01], avg - CELL_MAX_CORNER_DELTA, avg + CELL_MAX_CORNER_DELTA)
			levels[i11] = clampi(levels[i11], avg - CELL_MAX_CORNER_DELTA, avg + CELL_MAX_CORNER_DELTA)

	state["cell_levels"] = levels
	_tiles[key] = state

	var cell_analysis := _analyze_cells(levels)
	var cell_avgs: PackedInt32Array = cell_analysis["averages"]
	var cell_slopes: PackedInt32Array = cell_analysis["slopes"]
	state["native_cell_analysis"] = _native_core != null
	state["native_cliff_candidates"] = int(cell_analysis.get("cliff_edges", 0))
	_tiles[key] = state

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for gy in range(CELL_GRID):
		var v0 := float(gy) / float(CELL_GRID)
		var v1 := float(gy + 1) / float(CELL_GRID)
		for gx in range(CELL_GRID):
			var u0 := float(gx) / float(CELL_GRID)
			var u1 := float(gx + 1) / float(CELL_GRID)

			var i00 := gy * (CELL_GRID + 1) + gx
			var i10 := i00 + 1
			var i01 := i00 + CELL_GRID + 1
			var i11 := i01 + 1

			var l00 := levels[i00]
			var l10 := levels[i10]
			var l01 := levels[i01]
			var l11 := levels[i11]
			var cell_index := gy * CELL_GRID + gx
			var avg_level := cell_avgs[cell_index]

			var p00 := _cell_vertex(z, x, y, u0, v0, l00)
			var p10 := _cell_vertex(z, x, y, u1, v0, l10)
			var p01 := _cell_vertex(z, x, y, u0, v1, l01)
			var p11 := _cell_vertex(z, x, y, u1, v1, l11)

			var local_slope := cell_slopes[cell_index]
			var color := _styled_ground_color(
				float(avg_level) * CELL_HEIGHT_STEP_M,
				local_slope,
				x, y, gx, gy
			)

			_add_colored_triangle(st, p00, p01, p10, color)
			_add_colored_triangle(st, p10, p01, p11, color)

	# Decorative cliff faces are generated from real height steps. The DEM is
	# not moved; these faces only make steep changes visually explicit.
	for gy in range(CELL_GRID):
		for gx in range(CELL_GRID):
			var here := cell_avgs[gy * CELL_GRID + gx]
			var u0 := float(gx) / float(CELL_GRID)
			var u1 := float(gx + 1) / float(CELL_GRID)
			var v0 := float(gy) / float(CELL_GRID)
			var v1 := float(gy + 1) / float(CELL_GRID)

			if gx + 1 < CELL_GRID:
				var east := cell_avgs[gy * CELL_GRID + gx + 1]
				if abs(here - east) >= CLIFF_MIN_LEVELS:
					_append_cliff_face(
						st, z, x, y,
						u1, v0, u1, v1,
						here, east,
						x + gx, y + gy
					)

			if gy + 1 < CELL_GRID:
				var south := cell_avgs[(gy + 1) * CELL_GRID + gx]
				if abs(here - south) >= CLIFF_MIN_LEVELS:
					_append_cliff_face(
						st, z, x, y,
						u0, v1, u1, v1,
						here, south,
						x + gx + 17, y + gy + 31
					)

	st.generate_normals()
	var mesh := st.commit()
	if mesh == null:
		return

	var node: MeshInstance3D = state.get("node")
	if not is_instance_valid(node):
		node = MeshInstance3D.new()
		node.name = "RTSTile_%d_%d_%d" % [z, x, y]
		terrain_root.add_child(node)

	node.mesh = mesh
	node.material_override = _make_ground_material(null)
	state["node"] = node
	_tiles[key] = state


func _analyze_cells(levels: PackedInt32Array) -> Dictionary:
	if _native_core != null:
		var native_result = _native_core.call(
			"analyze_cells",
			levels,
			CELL_GRID,
			CLIFF_MIN_LEVELS
		)
		if typeof(native_result) == TYPE_DICTIONARY:
			var averages: PackedInt32Array = native_result.get("averages", PackedInt32Array())
			var slopes: PackedInt32Array = native_result.get("slopes", PackedInt32Array())
			if averages.size() == CELL_GRID * CELL_GRID and slopes.size() == CELL_GRID * CELL_GRID:
				return native_result

	# Development fallback. Production CI requires the native core, but this
	# keeps the project editable if a developer has not compiled GDExtension yet.
	var averages := PackedInt32Array()
	var slopes := PackedInt32Array()
	averages.resize(CELL_GRID * CELL_GRID)
	slopes.resize(CELL_GRID * CELL_GRID)
	var cliff_edges := 0

	for gy in range(CELL_GRID):
		for gx in range(CELL_GRID):
			var i00 := gy * (CELL_GRID + 1) + gx
			var i10 := i00 + 1
			var i01 := i00 + CELL_GRID + 1
			var i11 := i01 + 1
			var l00 := levels[i00]
			var l10 := levels[i10]
			var l01 := levels[i01]
			var l11 := levels[i11]
			var index := gy * CELL_GRID + gx
			averages[index] = int(round(
				(float(l00) + float(l10) + float(l01) + float(l11)) * 0.25
			))
			slopes[index] = maxi(
				maxi(abs(l00 - l11), abs(l10 - l01)),
				maxi(abs(l00 - l10), abs(l00 - l01))
			)

	for gy in range(CELL_GRID):
		for gx in range(CELL_GRID):
			var here := averages[gy * CELL_GRID + gx]
			if gx + 1 < CELL_GRID and abs(here - averages[gy * CELL_GRID + gx + 1]) >= CLIFF_MIN_LEVELS:
				cliff_edges += 1
			if gy + 1 < CELL_GRID and abs(here - averages[(gy + 1) * CELL_GRID + gx]) >= CLIFF_MIN_LEVELS:
				cliff_edges += 1

	return {
		"averages": averages,
		"slopes": slopes,
		"cliff_edges": cliff_edges,
		"native": false,
	}


func _add_colored_triangle(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color: Color
) -> void:
	st.set_color(color); st.add_vertex(a)
	st.set_color(color); st.add_vertex(b)
	st.set_color(color); st.add_vertex(c)


func _append_cliff_face(
	st: SurfaceTool,
	z: int,
	x: int,
	y: int,
	u0: float,
	v0: float,
	u1: float,
	v1: float,
	level_a: int,
	level_b: int,
	noise_x: int,
	noise_y: int
) -> void:
	var high := maxi(level_a, level_b)
	var low := mini(level_a, level_b)
	var top0 := _cell_vertex(z, x, y, u0, v0, high)
	var top1 := _cell_vertex(z, x, y, u1, v1, high)
	var bottom0 := _cell_vertex(z, x, y, u0, v0, low)
	var bottom1 := _cell_vertex(z, x, y, u1, v1, low)
	var rock := _cliff_color(float(high) * CELL_HEIGHT_STEP_M, noise_x, noise_y)

	_add_colored_triangle(st, top0, bottom0, top1, rock)
	_add_colored_triangle(st, top1, bottom0, bottom1, rock)
	_cliff_face_count += 1


func _styled_ground_color(
	elevation_m: float,
	slope_steps: int,
	tile_x: int,
	tile_y: int,
	cell_x: int,
	cell_y: int
) -> Color:
	var base := _cell_terrain_color(elevation_m)
	var fine := _hash_noise(tile_x * 53 + cell_x, tile_y * 47 + cell_y)
	var patch := _hash_noise(tile_x * 11 + int(cell_x / 4), tile_y * 13 + int(cell_y / 4))
	var factor := 0.88 + fine * 0.22

	if patch > 0.68:
		base = base.lerp(Color(0.59, 0.49, 0.27, 1.0), 0.25)
	elif patch < 0.20:
		base = base.lerp(Color(0.34, 0.43, 0.23, 1.0), 0.18)

	if slope_steps >= CLIFF_MIN_LEVELS:
		base = base.lerp(Color(0.55, 0.36, 0.18, 1.0), 0.28)

	return Color(
		clampf(base.r * factor, 0.0, 1.0),
		clampf(base.g * factor, 0.0, 1.0),
		clampf(base.b * factor, 0.0, 1.0),
		1.0
	)


func _cliff_color(elevation_m: float, x: int, y: int) -> Color:
	var n := _hash_noise(x * 7, y * 11)
	var base := Color(0.55, 0.31, 0.14, 1.0)
	if elevation_m > 900.0:
		base = Color(0.46, 0.36, 0.27, 1.0)
	return base.lerp(Color(0.72, 0.49, 0.24, 1.0), n * 0.38)


func _hash_noise(x: int, y: int) -> float:
	var value := sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
	return value - floor(value)

func _build_map_quad(
	state: Dictionary,
	key: String,
	z: int,
	x: int,
	y: int,
	map_texture: Texture2D
) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var nw := _tile_fraction_to_lon_lat(z, x, y, 0.0, 0.0)
	var ne := _tile_fraction_to_lon_lat(z, x, y, 1.0, 0.0)
	var sw := _tile_fraction_to_lon_lat(z, x, y, 0.0, 1.0)
	var se := _tile_fraction_to_lon_lat(z, x, y, 1.0, 1.0)

	var p00 := _geo_to_local(nw.x, nw.y, 0.0)
	var p10 := _geo_to_local(ne.x, ne.y, 0.0)
	var p01 := _geo_to_local(sw.x, sw.y, 0.0)
	var p11 := _geo_to_local(se.x, se.y, 0.0)

	st.set_uv(Vector2(0, 0)); st.add_vertex(p00)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p01)
	st.set_uv(Vector2(1, 0)); st.add_vertex(p10)
	st.set_uv(Vector2(1, 0)); st.add_vertex(p10)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p01)
	st.set_uv(Vector2(1, 1)); st.add_vertex(p11)

	var mesh := st.commit()
	if mesh == null:
		return

	var node: MeshInstance3D = state.get("node")
	if not is_instance_valid(node):
		node = MeshInstance3D.new()
		node.name = "MapTile_%d_%d_%d" % [z, x, y]
		terrain_root.add_child(node)

	node.mesh = mesh
	node.material_override = _make_ground_material(map_texture)
	state["node"] = node
	_tiles[key] = state


func _cell_vertex(z: int, x: int, y: int, u: float, v: float, level: int) -> Vector3:
	var geo := _tile_fraction_to_lon_lat(z, x, y, u, v)
	var height_km := (
		float(level) * CELL_HEIGHT_STEP_M / 1000.0 * VERTICAL_EXAGGERATION
	)
	return _geo_to_local(geo.x, geo.y, height_km)


func _cell_terrain_color(elevation_m: float) -> Color:
	# High-contrast RTS palette. Geographic shape remains real; palette is
	# deliberately art-directed for readability at battlefield zoom.
	if elevation_m < 250.0:
		return Color(0.53, 0.49, 0.28, 1.0)
	if elevation_m < 450.0:
		return Color(0.48, 0.49, 0.27, 1.0)
	if elevation_m < 700.0:
		return Color(0.43, 0.44, 0.25, 1.0)
	if elevation_m < 1100.0:
		return Color(0.43, 0.39, 0.27, 1.0)
	return Color(0.50, 0.47, 0.39, 1.0)


func _make_ground_material(map_texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0

	if not _terrain_mode:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = false
		if map_texture != null:
			material.albedo_texture = map_texture
			material.albedo_color = Color.WHITE
		else:
			material.albedo_color = Color(0.52, 0.52, 0.52, 1.0)
	return material


func _terrain_color(elevation_m: float) -> Color:
	if elevation_m < 20.0:
		return Color(0.57, 0.51, 0.36, 1.0)
	if elevation_m < 350.0:
		return Color(0.49, 0.44, 0.30, 1.0)
	if elevation_m < 900.0:
		return Color(0.40, 0.39, 0.27, 1.0)
	if elevation_m < 1800.0:
		return Color(0.37, 0.35, 0.30, 1.0)
	return Color(0.54, 0.53, 0.50, 1.0)


func _refresh_vector_data(force: bool) -> void:
	if not _terrain_mode or _vector_inflight:
		return

	# The bundled Aleppo sector already covers the current test battlefield.
	# Do not parse/rebuild thousands of real-world features on every pan.
	if _vector_loaded and not force:
		return

	_vector_inflight = true
	_last_vector_center = Vector2(_center_lon, _center_lat)

	if force:
		_clear_vector_nodes()

	_update_status()

	var data_path := _governorate_data_path()
	if not FileAccess.file_exists(data_path):
		_vector_inflight = false
		_vector_loaded = false
		status_label.text = "%s DATA MISSING" % _governorate_name()
		return

	var file := FileAccess.open(data_path, FileAccess.READ)
	if file == null:
		_vector_inflight = false
		_vector_loaded = false
		status_label.text = "%s DATA ERROR" % _governorate_name()
		return

	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	raw = ""

	if typeof(parsed) == TYPE_DICTIONARY:
		_build_vector_world(parsed)
		_vector_loaded = true
		_add_fallback_governorate_label()
	else:
		_vector_loaded = false

	_vector_inflight = false
	_update_status()

func _governorate() -> Dictionary:
	return GOVERNORATES[_governorate_index]


func _governorate_name() -> String:
	return str(_governorate().get("name_ar", _governorate().get("name_en", "")))


func _governorate_data_path() -> String:
	return "res://source/world/data/syria_%s.json" % str(_governorate()["slug"])


func _update_governorate_ui() -> void:
	governorate_label.text = "%d / %d   %s" % [
		_governorate_index + 1,
		GOVERNORATES.size(),
		_governorate_name()
	]


func _select_governorate(index: int) -> void:
	_governorate_index = posmod(index, GOVERNORATES.size())
	var gov := _governorate()
	_center_lon = float(gov["lon"])
	_center_lat = float(gov["lat"])
	_origin_lon = _center_lon
	_origin_lat = _center_lat
	_map_zoom = DEFAULT_MAP_ZOOM

	_clear_all_world_nodes()
	_update_governorate_ui()
	_position_camera()
	_refresh_tiles()
	_update_status()

	if _terrain_mode:
		call_deferred("_refresh_vector_data", true)


func _on_previous_governorate_pressed() -> void:
	_select_governorate(_governorate_index - 1)


func _on_next_governorate_pressed() -> void:
	_select_governorate(_governorate_index + 1)


func _add_fallback_governorate_label() -> void:
	var text := _governorate_name()
	for child in labels_root.get_children():
		if child is Label3D and child.text == text:
			return

	var gov := _governorate()
	var lon := float(gov["lon"])
	var lat := float(gov["lat"])
	var label := Label3D.new()
	label.text = text
	label.position = _geo_to_local(lon, lat, _height_at_geo(lon, lat) + 0.18)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = false
	label.font_size = 36
	label.pixel_size = 0.0021
	label.outline_size = 4
	label.visibility_range_end = 45.0
	label.modulate = Color(0.98, 0.95, 0.82, 0.94)
	label.outline_modulate = Color(0.06, 0.06, 0.06, 0.94)
	labels_root.add_child(label)

func _build_vector_world(data: Dictionary) -> void:
	var elements: Array = data.get("elements", [])

	_feature_count = 0
	_road_feature_count = 0
	_building_feature_count = 0
	_water_feature_count = 0
	_landcover_feature_count = 0
	_tree_instance_count = 0

	var landcover := SurfaceTool.new()
	var road_shoulders := SurfaceTool.new()
	var roads := SurfaceTool.new()
	var buildings := SurfaceTool.new()
	var water_banks := SurfaceTool.new()
	var water := SurfaceTool.new()

	landcover.begin(Mesh.PRIMITIVE_TRIANGLES)
	road_shoulders.begin(Mesh.PRIMITIVE_TRIANGLES)
	roads.begin(Mesh.PRIMITIVE_TRIANGLES)
	buildings.begin(Mesh.PRIMITIVE_TRIANGLES)
	water_banks.begin(Mesh.PRIMITIVE_TRIANGLES)
	water.begin(Mesh.PRIMITIVE_TRIANGLES)

	var forest_trees: Array[Transform3D] = []
	var orchard_trees: Array[Transform3D] = []
	var building_limit := 1200

	for element in elements:
		if typeof(element) != TYPE_DICTIONARY:
			continue

		var tags: Dictionary = element.get("tags", {})
		var element_type: String = element.get("type", "")

		if element_type == "node" and tags.has("place"):
			var place_type := str(tags.get("place", ""))
			if place_type in ["city", "town", "village"]:
				_add_place_label(element, tags)
			continue

		var geometry: Array = element.get("geometry", [])
		if geometry.size() < 2:
			continue

		if tags.has("dam:landcover"):
			if _append_landcover_geometry(
				landcover, geometry, tags,
				forest_trees, orchard_trees
			):
				_landcover_feature_count += 1
		elif tags.has("highway"):
			if _append_road_geometry(roads, road_shoulders, geometry, tags):
				_road_feature_count += 1
		elif tags.has("building") and _building_feature_count < building_limit:
			if _append_building_geometry(buildings, geometry, tags):
				_building_feature_count += 1
		elif tags.has("waterway") or tags.get("natural", "") == "water":
			if _append_water_geometry(water, water_banks, geometry):
				_water_feature_count += 1

	_feature_count = (
		_road_feature_count + _building_feature_count
		+ _water_feature_count + _landcover_feature_count
	)

	if _landcover_feature_count > 0:
		_commit_vertex_color_batch(landcover, "LandcoverBatch")
	if _road_feature_count > 0:
		_commit_vector_batch(road_shoulders, "RoadShoulderBatch", Color(0.55, 0.44, 0.27, 1.0))
		_commit_vector_batch(roads, "RoadBatch", Color(0.20, 0.19, 0.18, 1.0))
	if _building_feature_count > 0:
		_commit_vector_batch(buildings, "BuildingBatch", Color(0.76, 0.68, 0.59, 1.0))
	if _water_feature_count > 0:
		_commit_vector_batch(water_banks, "WaterBankBatch", Color(0.48, 0.40, 0.24, 1.0))
		_commit_vector_batch(water, "WaterBatch", Color(0.08, 0.30, 0.50, 1.0))

	_commit_tree_multimesh(
		forest_trees, "ForestTrees",
		Color(0.18, 0.34, 0.12, 1.0)
	)
	_commit_tree_multimesh(
		orchard_trees, "OrchardTrees",
		Color(0.28, 0.40, 0.15, 1.0)
	)
	_tree_instance_count = forest_trees.size() + orchard_trees.size()


func _append_landcover_geometry(
	st: SurfaceTool,
	geometry: Array,
	tags: Dictionary,
	forest_trees: Array[Transform3D],
	orchard_trees: Array[Transform3D]
) -> bool:
	if geometry.size() < 4:
		return false

	var kind := str(tags.get("dam:landcover", ""))
	var local_points: Array[Vector3] = []
	var geo_polygon := PackedVector2Array()

	for p in geometry:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var lon := float(p.get("lon", 0.0))
		var lat := float(p.get("lat", 0.0))
		var h := _height_at_geo(lon, lat) + 0.0025
		local_points.append(_geo_to_local(lon, lat, h))
		geo_polygon.append(Vector2(lon, lat))

	if local_points.size() < 4:
		return false

	if local_points[0].distance_to(local_points[local_points.size() - 1]) < 0.0005:
		local_points.pop_back()
		geo_polygon.resize(geo_polygon.size() - 1)

	if local_points.size() < 3:
		return false

	var polygon2d := PackedVector2Array()
	for p in local_points:
		polygon2d.append(Vector2(p.x, p.z))

	var triangles := Geometry2D.triangulate_polygon(polygon2d)
	if triangles.is_empty():
		return false

	var color := _landcover_color(kind)
	for i in range(0, triangles.size(), 3):
		var a := local_points[triangles[i]]
		var b := local_points[triangles[i + 1]]
		var c := local_points[triangles[i + 2]]
		_add_colored_triangle(st, a, b, c, color)

	if kind in ["forest", "park"] and forest_trees.size() < MAX_FOREST_TREES:
		_scatter_trees_in_polygon(geo_polygon, kind, forest_trees, MAX_FOREST_TREES)
	elif kind == "orchard" and orchard_trees.size() < MAX_ORCHARD_TREES:
		_scatter_trees_in_polygon(geo_polygon, kind, orchard_trees, MAX_ORCHARD_TREES)

	return true


func _landcover_color(kind: String) -> Color:
	match kind:
		"forest":
			return Color(0.24, 0.38, 0.17, 1.0)
		"orchard":
			return Color(0.36, 0.44, 0.19, 1.0)
		"farmland":
			return Color(0.52, 0.50, 0.27, 1.0)
		"meadow":
			return Color(0.42, 0.50, 0.25, 1.0)
		"scrub":
			return Color(0.43, 0.43, 0.24, 1.0)
		"park":
			return Color(0.29, 0.46, 0.20, 1.0)
		_:
			return Color(0.46, 0.45, 0.26, 1.0)


func _scatter_trees_in_polygon(
	polygon: PackedVector2Array,
	kind: String,
	out: Array[Transform3D],
	max_count: int
) -> void:
	if polygon.size() < 3 or out.size() >= max_count:
		return

	var min_lon := polygon[0].x
	var max_lon := polygon[0].x
	var min_lat := polygon[0].y
	var max_lat := polygon[0].y
	for p in polygon:
		min_lon = minf(min_lon, p.x)
		max_lon = maxf(max_lon, p.x)
		min_lat = minf(min_lat, p.y)
		max_lat = maxf(max_lat, p.y)

	var lat_km := (max_lat - min_lat) * 111.0
	var lon_km := (max_lon - min_lon) * 111.0 * maxf(0.2, cos(deg_to_rad((min_lat + max_lat) * 0.5)))
	var area_km2 := maxf(0.0001, lat_km * lon_km)
	var density := 95.0 if kind in ["forest", "park"] else 125.0
	var target := clampi(int(area_km2 * density), 3, 90)
	target = mini(target, max_count - out.size())

	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(hash("%s|%.6f|%.6f|%.6f|%.6f" % [
		kind, min_lon, min_lat, max_lon, max_lat
	])))

	var placed := 0
	var attempts := maxi(24, target * 10)
	for _attempt in range(attempts):
		if placed >= target or out.size() >= max_count:
			break
		var lon := rng.randf_range(min_lon, max_lon)
		var lat := rng.randf_range(min_lat, max_lat)
		if not Geometry2D.is_point_in_polygon(Vector2(lon, lat), polygon):
			continue

		var h := _height_at_geo(lon, lat) + 0.002
		var origin := _geo_to_local(lon, lat, h)
		var size_jitter := rng.randf_range(0.78, 1.22)
		var width := (0.0085 if kind in ["forest", "park"] else 0.0065) * size_jitter
		var height := (0.017 if kind in ["forest", "park"] else 0.011) * size_jitter
		var rotation := rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, rotation).scaled(Vector3(width, height, width))
		out.append(Transform3D(basis, origin))
		placed += 1


func _commit_tree_multimesh(
	transforms: Array[Transform3D],
	node_name: String,
	canopy_color: Color
) -> void:
	if transforms.is_empty():
		return

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _make_tree_mesh(canopy_color)
	multimesh.instance_count = transforms.size()

	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	vegetation_root.add_child(node)


func _make_tree_mesh(canopy_color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var trunk := Color(0.25, 0.16, 0.08, 1.0)
	var half := 0.085
	var trunk_top := 0.42

	var base := [
		Vector3(-half, 0.0, -half),
		Vector3( half, 0.0, -half),
		Vector3( half, 0.0,  half),
		Vector3(-half, 0.0,  half)
	]
	var top := [
		Vector3(-half, trunk_top, -half),
		Vector3( half, trunk_top, -half),
		Vector3( half, trunk_top,  half),
		Vector3(-half, trunk_top,  half)
	]

	for i in range(4):
		var j := (i + 1) % 4
		_add_colored_triangle(st, base[i], base[j], top[i], trunk)
		_add_colored_triangle(st, top[i], base[j], top[j], trunk)

	var ring: Array[Vector3] = []
	var sides := 7
	for i in range(sides):
		var a := TAU * float(i) / float(sides)
		ring.append(Vector3(cos(a) * 0.40, 0.34, sin(a) * 0.40))
	var apex := Vector3(0.0, 1.0, 0.0)
	var underside := Vector3(0.0, 0.30, 0.0)

	for i in range(sides):
		var j := (i + 1) % sides
		var shade := 0.88 + 0.12 * float(i % 2)
		var leaf := Color(
			canopy_color.r * shade,
			canopy_color.g * shade,
			canopy_color.b * shade,
			1.0
		)
		_add_colored_triangle(st, apex, ring[i], ring[j], leaf)
		_add_colored_triangle(st, underside, ring[j], ring[i], leaf.darkened(0.12))

	st.generate_normals()
	return st.commit()


func _append_road_geometry(
	st: SurfaceTool,
	shoulders: SurfaceTool,
	geometry: Array,
	tags: Dictionary
) -> bool:
	var highway: String = str(tags.get("highway", "road"))
	var width_m := 5.0
	if highway in ["motorway", "trunk"]:
		width_m = 18.0
	elif highway in ["primary", "secondary"]:
		width_m = 12.0
	elif highway in ["tertiary", "residential"]:
		width_m = 8.0
	elif highway in ["service", "living_street"]:
		width_m = 5.0

	var points: Array[Vector3] = []
	for p in geometry:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var lon := float(p.get("lon", 0.0))
		var lat := float(p.get("lat", 0.0))
		var h := _height_at_geo(lon, lat)
		points.append(_geo_to_local(lon, lat, h))

	if points.size() < 2:
		return false

	var width_km := width_m / 1000.0
	var shoulder_ok := _append_ribbon_geometry(shoulders, points, width_km * 1.55, 0.004)
	var road_ok := _append_ribbon_geometry(st, points, width_km, 0.006)
	return shoulder_ok or road_ok


func _append_water_geometry(
	st: SurfaceTool,
	banks: SurfaceTool,
	geometry: Array
) -> bool:
	var points: Array[Vector3] = []
	for p in geometry:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var lon := float(p.get("lon", 0.0))
		var lat := float(p.get("lat", 0.0))
		var h := _height_at_geo(lon, lat)
		points.append(_geo_to_local(lon, lat, h))

	if points.size() < 2:
		return false

	var bank_ok := _append_ribbon_geometry(banks, points, 0.030, 0.003)
	var water_ok := _append_ribbon_geometry(st, points, 0.018, 0.005)
	return bank_ok or water_ok


func _append_ribbon_geometry(
	st: SurfaceTool,
	points: Array[Vector3],
	width_km: float,
	y_offset: float
) -> bool:
	var added := false
	for i in range(points.size() - 1):
		var a := points[i] + Vector3.UP * y_offset
		var b := points[i + 1] + Vector3.UP * y_offset
		var delta := Vector2(b.x - a.x, b.z - a.z)
		if delta.length() < 0.0005:
			continue
		var direction := delta.normalized()
		var side := Vector3(-direction.y, 0.0, direction.x) * width_km * 0.5
		var a0 := a - side
		var a1 := a + side
		var b0 := b - side
		var b1 := b + side
		st.add_vertex(a0)
		st.add_vertex(b0)
		st.add_vertex(a1)
		st.add_vertex(a1)
		st.add_vertex(b0)
		st.add_vertex(b1)
		added = true
	return added


func _append_building_geometry(st: SurfaceTool, geometry: Array, tags: Dictionary) -> bool:
	if geometry.size() < 4:
		return false

	var pts: Array[Vector3] = []
	for p in geometry:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var lon := float(p.get("lon", 0.0))
		var lat := float(p.get("lat", 0.0))
		var h := _height_at_geo(lon, lat)
		pts.append(_geo_to_local(lon, lat, h))

	if pts.size() < 4:
		return false

	var count := pts.size()
	if pts[0].distance_to(pts[count - 1]) < 0.001:
		count -= 1
	if count < 3:
		return false

	var height_m := 9.0
	if tags.has("height"):
		var raw_height := str(tags["height"]).replace(" m", "")
		if raw_height.is_valid_float():
			height_m = clampf(raw_height.to_float(), 3.0, 120.0)
	elif tags.has("building:levels"):
		var raw_levels := str(tags["building:levels"])
		if raw_levels.is_valid_float():
			height_m = clampf(raw_levels.to_float() * 3.1, 3.0, 120.0)

	var height_km := height_m / 1000.0 * VERTICAL_EXAGGERATION
	var center := Vector3.ZERO
	for i in range(count):
		center += pts[i]
	center /= float(count)
	var roof_center := center + Vector3.UP * height_km

	for i in range(count):
		var j := (i + 1) % count
		var a := pts[i]
		var b := pts[j]
		var at := a + Vector3.UP * height_km
		var bt := b + Vector3.UP * height_km
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(at)
		st.add_vertex(at); st.add_vertex(b); st.add_vertex(bt)
		st.add_vertex(roof_center); st.add_vertex(at); st.add_vertex(bt)

	return true


func _commit_vertex_color_batch(st: SurfaceTool, node_name: String) -> void:
	st.generate_normals()
	var mesh := st.commit()
	if mesh == null:
		return
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = _make_vertex_color_material()
	vector_root.add_child(node)


func _make_vertex_color_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _commit_vector_batch(st: SurfaceTool, node_name: String, color: Color) -> void:
	st.generate_normals()
	var mesh := st.commit()
	if mesh == null:
		return
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = _solid_material(color)
	vector_root.add_child(node)

func _add_place_label(element: Dictionary, tags: Dictionary) -> void:
	var text := str(tags.get("name:ar", tags.get("name", "")))
	if text.is_empty():
		return

	var place_type := str(tags.get("place", ""))
	var lon := float(element.get("lon", 0.0))
	var lat := float(element.get("lat", 0.0))
	var h := _height_at_geo(lon, lat) + 0.035

	var label := Label3D.new()
	label.text = text
	label.position = _geo_to_local(lon, lat, h)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	# Never use fixed-size labels in the RTS battlefield. Fixed-size text stays
	# the same number of screen pixels at every distance and caused the giant
	# overlapping Arabic words seen on Android.
	label.fixed_size = false
	label.pixel_size = 0.0016
	label.outline_size = 3
	label.modulate = Color(0.96, 0.94, 0.84, 0.92)
	label.outline_modulate = Color(0.06, 0.06, 0.06, 0.92)

	# Map-like label hierarchy: important places remain readable from farther
	# away; local names become small and disappear sooner.
	match place_type:
		"city":
			label.font_size = 34
			label.pixel_size = 0.0020
			label.visibility_range_end = 40.0
		"town":
			label.font_size = 28
			label.pixel_size = 0.0018
			label.visibility_range_end = 25.0
		"village":
			label.font_size = 22
			label.pixel_size = 0.0016
			label.visibility_range_end = 14.0
		"suburb":
			label.font_size = 18
			label.pixel_size = 0.0015
			label.visibility_range_end = 8.0
		"neighbourhood":
			label.font_size = 16
			label.pixel_size = 0.0014
			label.visibility_range_end = 5.0
		"hamlet":
			label.font_size = 14
			label.pixel_size = 0.0013
			label.visibility_range_end = 4.0
		_:
			label.font_size = 18
			label.visibility_range_end = 8.0

	labels_root.add_child(label)

func _make_ribbon(points: Array[Vector3], width_km: float) -> ArrayMesh:
	if points.size() < 2:
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var direction := Vector2(b.x - a.x, b.z - a.z).normalized()
		if direction.length() < 0.001:
			continue

		var side := Vector3(-direction.y, 0.0, direction.x) * width_km * 0.5
		var a0 := a - side
		var a1 := a + side
		var b0 := b - side
		var b1 := b + side

		st.add_vertex(a0)
		st.add_vertex(b0)
		st.add_vertex(a1)
		st.add_vertex(a1)
		st.add_vertex(b0)
		st.add_vertex(b1)

	var mesh := st.commit()
	return mesh


func _make_building_mesh(points: Array[Vector3], height_km: float) -> ArrayMesh:
	if points.size() < 4:
		return null

	# OSM polygons usually repeat the first point. Ignore the duplicate.
	var count := points.size()
	if points[0].distance_to(points[count - 1]) < 0.001:
		count -= 1
	if count < 3:
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var center := Vector3.ZERO
	for i in range(count):
		center += points[i]
	center /= float(count)
	var roof_center := center + Vector3.UP * height_km

	for i in range(count):
		var j := (i + 1) % count
		var a := points[i]
		var b := points[j]
		var at := a + Vector3.UP * height_km
		var bt := b + Vector3.UP * height_km

		# wall
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(at)
		st.add_vertex(at)
		st.add_vertex(b)
		st.add_vertex(bt)

		# roof fan
		st.add_vertex(roof_center)
		st.add_vertex(at)
		st.add_vertex(bt)

	st.generate_normals()
	return st.commit()


func _solid_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _height_at_geo(lon: float, lat: float) -> float:
	if not _terrain_mode:
		return 0.0

	var tile := _lon_lat_to_tile(lon, lat, TERRAIN_ZOOM)
	var key := _tile_key(TERRAIN_ZOOM, tile.x, tile.y)
	if not _tiles.has(key):
		return 0.0

	var state: Dictionary = _tiles[key]
	var image: Image = state.get("dem_image")
	if image == null:
		return 0.0

	var uv := _lon_lat_to_tile_uv(lon, lat, TERRAIN_ZOOM, tile.x, tile.y)
	var meters := _sample_dem(image, uv.x, uv.y)
	return meters / 1000.0 * VERTICAL_EXAGGERATION


func _sample_dem(image: Image, u: float, v: float) -> float:
	var px := clampi(int(round(u * float(image.get_width() - 1))), 0, image.get_width() - 1)
	var py := clampi(int(round(v * float(image.get_height() - 1))), 0, image.get_height() - 1)
	return _decode_terrarium(image.get_pixel(px, py))


func _decode_terrarium(color: Color) -> float:
	var red := int(round(color.r * 255.0))
	var green := int(round(color.g * 255.0))
	var blue := int(round(color.b * 255.0))
	return float(red * 256 + green) + float(blue) / 256.0 - 32768.0


func _geo_to_local(lon_deg: float, lat_deg: float, height_km: float) -> Vector3:
	var mean_lat := deg_to_rad((lat_deg + _origin_lat) * 0.5)
	var east := EARTH_RADIUS_KM * deg_to_rad(lon_deg - _origin_lon) * cos(mean_lat)
	var north := EARTH_RADIUS_KM * deg_to_rad(lat_deg - _origin_lat)
	return Vector3(east, height_km, -north)


func _map_tile_width_km() -> float:
	return (
		TAU * EARTH_RADIUS_KM * maxf(0.15, cos(deg_to_rad(_center_lat)))
		/ pow(2.0, float(_map_zoom))
	)


func _lon_lat_to_tile(lon: float, lat: float, z: int) -> Vector2i:
	var n := pow(2.0, float(z))
	var safe_lat := clampf(lat, -85.05112878, 85.05112878)
	var x := int(floor((lon + 180.0) / 360.0 * n))
	var lat_rad := deg_to_rad(safe_lat)
	var y := int(floor((1.0 - asinh(tan(lat_rad)) / PI) * 0.5 * n))
	return Vector2i(x, y)


func _lon_lat_to_tile_uv(lon: float, lat: float, z: int, x: int, y: int) -> Vector2:
	var n := pow(2.0, float(z))
	var xf := (lon + 180.0) / 360.0 * n
	var lat_rad := deg_to_rad(clampf(lat, -85.05112878, 85.05112878))
	var yf := (1.0 - asinh(tan(lat_rad)) / PI) * 0.5 * n
	return Vector2(xf - float(x), yf - float(y))


func _tile_fraction_to_lon_lat(z: int, x: int, y: int, u: float, v: float) -> Vector2:
	var n := pow(2.0, float(z))
	var xf := float(x) + u
	var yf := float(y) + v
	var lon := xf / n * 360.0 - 180.0
	var mercator := PI * (1.0 - 2.0 * yf / n)
	var lat := rad_to_deg(atan(sinh(mercator)))
	return Vector2(lon, lat)


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


func _clear_tiles() -> void:
	for key in _tiles.keys().duplicate():
		_remove_tile(key)
	_required_keys.clear()
	_keep_keys.clear()
	_pending.clear()
	_queued.clear()


func _clear_vector_nodes() -> void:
	for child in vector_root.get_children():
		child.free()
	for child in vegetation_root.get_children():
		child.free()
	for child in labels_root.get_children():
		child.free()
	_feature_count = 0
	_road_feature_count = 0
	_building_feature_count = 0
	_water_feature_count = 0
	_landcover_feature_count = 0
	_tree_instance_count = 0


func _clear_all_world_nodes() -> void:
	_clear_tiles()
	_clear_vector_nodes()
	_last_vector_center = Vector2(999.0, 999.0)
	_vector_loaded = false


func _note_failure(kind: String) -> void:
	if kind == "map":
		_failed_map += 1
	else:
		_failed_dem += 1


func _update_status() -> void:
	if _terrain_mode:
		zoom_label.text = "REAL TERRAIN"
	else:
		zoom_label.text = "ZOOM %d / %d" % [_map_zoom, MAX_MAP_ZOOM]

	var loading := _active_requests + _pending.size()
	if _terrain_mode and _vector_inflight:
		loading += 1

	if loading > 0:
		status_label.text = ("%s TERRAIN" % _governorate_name() if _terrain_mode else "%s MAP" % _governorate_name()) + " • LOADING %d" % loading
	else:
		if _terrain_mode:
			status_label.text = "%s • R%d B%d V%d T%d" % [
				_governorate_name(),
				_road_feature_count,
				_building_feature_count,
				_landcover_feature_count,
				_tree_instance_count
			]
		else:
			status_label.text = "%s MAP READY" % _governorate_name()


func _on_mode_pressed() -> void:
	_terrain_mode = not _terrain_mode

	_origin_lon = _center_lon
	_origin_lat = _center_lat
	mode_button.text = "MAP" if _terrain_mode else "TERRAIN"

	_clear_all_world_nodes()
	_position_camera()
	_refresh_tiles()
	_update_status()

	if _terrain_mode:
		call_deferred("_refresh_vector_data", true)


func _on_zoom_in_pressed() -> void:
	if not _terrain_mode:
		_set_map_zoom(_map_zoom + 1)


func _on_zoom_out_pressed() -> void:
	if not _terrain_mode:
		_set_map_zoom(_map_zoom - 1)


func _on_reset_pressed() -> void:
	var gov := _governorate()
	_center_lon = float(gov["lon"])
	_center_lat = float(gov["lat"])
	_map_zoom = DEFAULT_MAP_ZOOM
	_origin_lon = _center_lon
	_origin_lat = _center_lat
	_clear_all_world_nodes()
	_position_camera()
	_refresh_tiles()
	if _terrain_mode:
		_refresh_vector_data(true)
	_update_status()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
