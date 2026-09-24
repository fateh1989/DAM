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
const ALEPPO_DATA_PATH := "res://source/world/data/aleppo_osm.json"
const ALEPPO_LAT := 36.201241
const ALEPPO_LON := 37.161173

const MAP_CACHE_ROOT := "user://dam_map_cache/osm"
const DEM_CACHE_ROOT := "user://dam_map_cache/terrarium"
const MAP_CACHE_MAX_AGE_SEC := 604800

const REGION_WEST := 24.0
const REGION_EAST := 64.5
const REGION_NORTH := 43.0
const REGION_SOUTH := 11.5

const EARTH_RADIUS_KM := 6371.0088
const VERTICAL_EXAGGERATION := 2.2

# Vector-detail query radius around current terrain camera.
const VECTOR_HALF_LAT := 0.055
const VECTOR_HALF_LON := 0.065
const VECTOR_REFRESH_DISTANCE_DEG := 0.025

@onready var terrain_root: Node3D = $TerrainRoot
@onready var vector_root: Node3D = $VectorRoot
@onready var labels_root: Node3D = $LabelsRoot
@onready var camera: Camera3D = $Camera3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var zoom_label: Label = $HUD/TopBar/Row/ZoomLabel
@onready var status_label: Label = $HUD/TopBar/Row/StatusLabel
@onready var mode_button: Button = $HUD/ModeButton

var _terrain_mode := false
var _map_zoom := DEFAULT_MAP_ZOOM
var _center_lon := ALEPPO_LON
var _center_lat := ALEPPO_LAT

var _origin_lon := ALEPPO_LON
var _origin_lat := ALEPPO_LAT

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


func _ready() -> void:
	_setup_environment()
	_origin_lon = _center_lon
	_origin_lat = _center_lat
	_position_camera()
	_refresh_tiles()
	_update_status()


func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.24, 0.34, 0.42, 1.0)
	environment.background_energy_multiplier = 0.8
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.74, 0.76, 1.0)
	environment.ambient_light_energy = 0.85
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
	if _terrain_mode:
		_refresh_vector_data(false)


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
		camera.position = center + Vector3(0.0, 7.6, 8.8)
		camera.look_at(center + Vector3(0.0, 0.25, 0.0), Vector3.UP)
		camera.fov = 48.0
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

	var segments := 56 if _terrain_mode else 1
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for gy in range(segments + 1):
		var v := float(gy) / float(segments)
		for gx in range(segments + 1):
			var u := float(gx) / float(segments)
			var elevation_m := 0.0
			if dem_image != null:
				elevation_m = _sample_dem(dem_image, u, v)

			var geo := _tile_fraction_to_lon_lat(z, x, y, u, v)
			var height_km := 0.0
			if _terrain_mode:
				height_km = elevation_m / 1000.0 * VERTICAL_EXAGGERATION

			var position := _geo_to_local(geo.x, geo.y, height_km)
			surface.set_uv(Vector2(u, v))
			surface.set_color(_terrain_color(elevation_m))
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
		node.name = "WorldTile_%d_%d_%d" % [z, x, y]
		terrain_root.add_child(node)

	node.mesh = mesh
	node.material_override = _make_ground_material(map_texture)
	state["node"] = node
	_tiles[key] = state


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
	if not _terrain_mode:
		return
	if _vector_inflight:
		return

	var now_center := Vector2(_center_lon, _center_lat)
	if _vector_loaded and not force and _last_vector_center.distance_to(now_center) < VECTOR_REFRESH_DISTANCE_DEG:
		return

	_vector_inflight = true
	_last_vector_center = now_center
	_clear_vector_nodes()
	_update_status()

	if not FileAccess.file_exists(ALEPPO_DATA_PATH):
		_vector_inflight = false
		_vector_loaded = false
		status_label.text = "ALEPPO DATA MISSING"
		return

	var file := FileAccess.open(ALEPPO_DATA_PATH, FileAccess.READ)
	if file == null:
		_vector_inflight = false
		_vector_loaded = false
		status_label.text = "ALEPPO DATA ERROR"
		return

	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)

	if typeof(parsed) == TYPE_DICTIONARY:
		_build_vector_world(parsed)
		_vector_loaded = true
		_add_fallback_aleppo_label()
	else:
		_vector_loaded = false

	_vector_inflight = false
	_update_status()


func _add_fallback_aleppo_label() -> void:
	for child in labels_root.get_children():
		if child is Label3D and child.text == "حلب":
			return

	var label := Label3D.new()
	label.text = "حلب"
	label.position = _geo_to_local(ALEPPO_LON, ALEPPO_LAT, _height_at_geo(ALEPPO_LON, ALEPPO_LAT) + 0.18)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.font_size = 44
	label.outline_size = 10
	label.modulate = Color(0.98, 0.95, 0.82, 1.0)
	label.outline_modulate = Color(0.06, 0.06, 0.06, 1.0)
	labels_root.add_child(label)

func _build_vector_world(data: Dictionary) -> void:
	var elements: Array = data.get("elements", [])
	var building_count := 0

	for element in elements:
		if typeof(element) != TYPE_DICTIONARY:
			continue

		var tags: Dictionary = element.get("tags", {})
		var element_type: String = element.get("type", "")

		if element_type == "node" and tags.has("place"):
			_add_place_label(element, tags)
			continue

		var geometry: Array = element.get("geometry", [])
		if geometry.size() < 2:
			continue

		if tags.has("highway"):
			_add_road(geometry, tags)
		elif tags.has("building") and building_count < 900:
			_add_building(geometry, tags)
			building_count += 1
		elif tags.has("waterway") or tags.get("natural", "") == "water":
			_add_water(geometry)


func _add_road(geometry: Array, tags: Dictionary) -> void:
	var highway: String = str(tags.get("highway", "road"))
	var width_m := 5.0
	if highway in ["motorway", "trunk"]:
		width_m = 18.0
	elif highway in ["primary", "secondary"]:
		width_m = 12.0
	elif highway in ["tertiary", "residential"]:
		width_m = 8.0

	var points: Array[Vector3] = []
	for p in geometry:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var lon := float(p.get("lon", 0.0))
		var lat := float(p.get("lat", 0.0))
		var h := _height_at_geo(lon, lat) + 0.006
		points.append(_geo_to_local(lon, lat, h))

	if points.size() < 2:
		return

	var mesh := _make_ribbon(points, width_m / 1000.0)
	if mesh == null:
		return

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _solid_material(Color(0.24, 0.23, 0.22, 1.0))
	vector_root.add_child(node)


func _add_building(geometry: Array, tags: Dictionary) -> void:
	if geometry.size() < 4:
		return

	var pts: Array[Vector3] = []
	for p in geometry:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var lon := float(p.get("lon", 0.0))
		var lat := float(p.get("lat", 0.0))
		var h := _height_at_geo(lon, lat)
		pts.append(_geo_to_local(lon, lat, h))

	if pts.size() < 4:
		return

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
	var mesh := _make_building_mesh(pts, height_km)
	if mesh == null:
		return

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _solid_material(Color(0.52, 0.47, 0.42, 1.0))
	vector_root.add_child(node)


func _add_water(geometry: Array) -> void:
	var points: Array[Vector3] = []
	for p in geometry:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var lon := float(p.get("lon", 0.0))
		var lat := float(p.get("lat", 0.0))
		var h := _height_at_geo(lon, lat) + 0.004
		points.append(_geo_to_local(lon, lat, h))

	if points.size() < 2:
		return

	var mesh := _make_ribbon(points, 0.018)
	if mesh == null:
		return

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _solid_material(Color(0.10, 0.32, 0.50, 1.0))
	vector_root.add_child(node)


func _add_place_label(element: Dictionary, tags: Dictionary) -> void:
	var text := str(tags.get("name:ar", tags.get("name", "")))
	if text.is_empty():
		return

	var lon := float(element.get("lon", 0.0))
	var lat := float(element.get("lat", 0.0))
	var h := _height_at_geo(lon, lat) + 0.10
	var label := Label3D.new()
	label.text = text
	label.position = _geo_to_local(lon, lat, h)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.font_size = 32
	label.outline_size = 8
	label.modulate = Color(0.96, 0.93, 0.82, 1.0)
	label.outline_modulate = Color(0.08, 0.08, 0.08, 1.0)
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
		child.queue_free()
	for child in labels_root.get_children():
		child.queue_free()


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
		status_label.text = ("ALEPPO TERRAIN" if _terrain_mode else "ALEPPO MAP") + " • LOADING %d" % loading
	else:
		if _terrain_mode:
			status_label.text = "ALEPPO • %d OBJECTS" % (vector_root.get_child_count() + labels_root.get_child_count())
		else:
			status_label.text = "ALEPPO MAP READY"


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
	_center_lon = ALEPPO_LON
	_center_lat = ALEPPO_LAT
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
