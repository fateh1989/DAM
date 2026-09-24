extends Control

# DAM real-world map prototype.
# The public OpenStreetMap tile service is used only for interactive prototype
# viewing. Tiles are requested on demand, cached after viewing, and never bulk
# prefetched. Production DAM should switch to a packaged/self-hosted source.

const TILE_SIZE := 256.0
const MIN_ZOOM := 4
const MAX_ZOOM := 10
const DEFAULT_ZOOM := 6
const MAX_PARALLEL_REQUESTS := 4
const TILE_URL_TEMPLATE := "https://tile.openstreetmap.org/%d/%d/%d.png"
const TILE_CACHE_ROOT := "user://dam_map_cache/osm"

# Test-region bounds. These are streaming bounds, not political boundaries.
const REGION_WEST := 24.0
const REGION_EAST := 64.5
const REGION_NORTH := 43.0
const REGION_SOUTH := 11.5

@onready var map_viewport: Control = $MapViewport
@onready var tile_layer: Control = $MapViewport/TileLayer
@onready var zoom_label: Label = $TopShade/ZoomLabel
@onready var status_label: Label = $TopShade/StatusLabel

var _zoom := DEFAULT_ZOOM
var _center_world := Vector2.ZERO
var _tile_nodes := {}
var _pending_tiles: Array = []
var _queued_keys := {}
var _inflight_keys := {}
var _active_requests := 0
var _request_failures := 0
var _touches := {}
var _pinch_accumulator := 0.0
var _last_pinch_distance := 0.0
var _mouse_dragging := false


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	call_deferred("_initialize_map")


func _initialize_map() -> void:
	if map_viewport.size.x <= 1.0 or map_viewport.size.y <= 1.0:
		await get_tree().process_frame
	_zoom = _best_fit_zoom()
	var center_lon := (REGION_WEST + REGION_EAST) * 0.5
	var center_lat := (REGION_NORTH + REGION_SOUTH) * 0.5
	_center_world = _geo_to_world(center_lon, center_lat, _zoom)
	_refresh_tiles()


func _best_fit_zoom() -> int:
	var viewport_size := map_viewport.size
	for candidate in range(MAX_ZOOM, MIN_ZOOM - 1, -1):
		var north_west := _geo_to_world(REGION_WEST, REGION_NORTH, candidate)
		var south_east := _geo_to_world(REGION_EAST, REGION_SOUTH, candidate)
		var region_size := Vector2(
			abs(south_east.x - north_west.x),
			abs(south_east.y - north_west.y)
		)
		if (
			region_size.x <= viewport_size.x * 0.94
			and region_size.y <= viewport_size.y * 0.88
		):
			return candidate
	return MIN_ZOOM


func _on_viewport_size_changed() -> void:
	if not is_node_ready():
		return
	_refresh_tiles()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_reset_pinch_reference()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		if not _touches.has(event.index):
			_touches[event.index] = event.position - event.relative

		if _touches.size() == 1:
			_touches[event.index] = event.position
			_pan_by(event.relative)
		else:
			var old_distance := _touch_distance()
			_touches[event.index] = event.position
			var new_distance := _touch_distance()
			if old_distance > 0.0 and new_distance > 0.0:
				_pinch_accumulator += new_distance - old_distance
				if abs(_pinch_accumulator) >= 30.0:
					_set_zoom(_zoom + (1 if _pinch_accumulator > 0.0 else -1))
					_pinch_accumulator = 0.0
			_last_pinch_distance = new_distance

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
		_pan_by(event.relative)
		get_viewport().set_input_as_handled()


func _reset_pinch_reference() -> void:
	_pinch_accumulator = 0.0
	_last_pinch_distance = _touch_distance()


func _touch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var ids := _touches.keys()
	var a: Vector2 = _touches[ids[0]]
	var b: Vector2 = _touches[ids[1]]
	return a.distance_to(b)


func _pan_by(screen_delta: Vector2) -> void:
	_center_world -= screen_delta
	_clamp_center()
	_refresh_tiles()


func _set_zoom(new_zoom: int) -> void:
	new_zoom = clampi(new_zoom, MIN_ZOOM, MAX_ZOOM)
	if new_zoom == _zoom:
		return

	var center_geo := _world_to_geo(_center_world, _zoom)
	_zoom = new_zoom
	_center_world = _geo_to_world(center_geo.x, center_geo.y, _zoom)

	_pending_tiles.clear()
	_queued_keys.clear()
	_clamp_center()
	_refresh_tiles()


func _refresh_tiles() -> void:
	if map_viewport.size.x <= 1.0 or map_viewport.size.y <= 1.0:
		return

	_clamp_center()

	var half_view := map_viewport.size * 0.5
	var buffer := Vector2(TILE_SIZE, TILE_SIZE)
	var world_min := _center_world - half_view - buffer
	var world_max := _center_world + half_view + buffer

	var min_tx := int(floor(world_min.x / TILE_SIZE))
	var max_tx := int(floor(world_max.x / TILE_SIZE))
	var min_ty := int(floor(world_min.y / TILE_SIZE))
	var max_ty := int(floor(world_max.y / TILE_SIZE))
	var tiles_per_axis := int(pow(2.0, float(_zoom)))

	min_tx = clampi(min_tx, 0, tiles_per_axis - 1)
	max_tx = clampi(max_tx, 0, tiles_per_axis - 1)
	min_ty = clampi(min_ty, 0, tiles_per_axis - 1)
	max_ty = clampi(max_ty, 0, tiles_per_axis - 1)

	var required := {}

	for ty in range(min_ty, max_ty + 1):
		for tx in range(min_tx, max_tx + 1):
			var key := _tile_key(_zoom, tx, ty)
			required[key] = true

			var tile: TextureRect
			if _tile_nodes.has(key):
				tile = _tile_nodes[key]
			else:
				tile = _create_tile(_zoom, tx, ty, key)

			var tile_world := Vector2(float(tx) * TILE_SIZE, float(ty) * TILE_SIZE)
			tile.position = tile_world - _center_world + half_view

	for key in _tile_nodes.keys().duplicate():
		if not required.has(key):
			var old_tile: TextureRect = _tile_nodes[key]
			if is_instance_valid(old_tile):
				old_tile.queue_free()
			_tile_nodes.erase(key)

	_pump_requests()
	_update_status()


func _create_tile(z: int, x: int, y: int, key: String) -> TextureRect:
	var tile := TextureRect.new()
	tile.name = "Tile_%d_%d_%d" % [z, x, y]
	tile.size = Vector2(TILE_SIZE + 1.0, TILE_SIZE + 1.0)
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_SCALE
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tile_layer.add_child(tile)
	_tile_nodes[key] = tile

	var cache_path := _cache_path(z, x, y)
	if FileAccess.file_exists(cache_path):
		var bytes := _read_file_bytes(cache_path)
		if not bytes.is_empty() and _apply_tile_bytes(key, bytes):
			return tile

	_queue_tile(z, x, y, key, cache_path)
	return tile


func _queue_tile(z: int, x: int, y: int, key: String, cache_path: String) -> void:
	if _queued_keys.has(key) or _inflight_keys.has(key):
		return
	_queued_keys[key] = true
	_pending_tiles.append({
		"z": z,
		"x": x,
		"y": y,
		"key": key,
		"cache_path": cache_path,
	})


func _pump_requests() -> void:
	while _active_requests < MAX_PARALLEL_REQUESTS and not _pending_tiles.is_empty():
		var item: Dictionary = _pending_tiles.pop_front()
		var key: String = item["key"]
		_queued_keys.erase(key)

		if not _tile_nodes.has(key):
			continue

		var request := HTTPRequest.new()
		request.use_threads = true
		request.timeout = 15.0
		add_child(request)

		_active_requests += 1
		_inflight_keys[key] = true
		request.request_completed.connect(
			_on_tile_request_completed.bind(request, item),
			CONNECT_ONE_SHOT
		)

		var url := TILE_URL_TEMPLATE % [item["z"], item["x"], item["y"]]
		var headers := PackedStringArray([
			"User-Agent: DAM-Android-RTS/0.1 (https://github.com/fateh1989/DAM)",
			"Accept: image/png",
		])
		var error := request.request(url, headers)
		if error != OK:
			_active_requests -= 1
			_inflight_keys.erase(key)
			_request_failures += 1
			request.queue_free()


func _on_tile_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	request: HTTPRequest,
	item: Dictionary
) -> void:
	_active_requests = maxi(0, _active_requests - 1)
	var key: String = item["key"]
	_inflight_keys.erase(key)

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if _apply_tile_bytes(key, body):
			_write_file_bytes(item["cache_path"], body)
	else:
		_request_failures += 1

	if is_instance_valid(request):
		request.queue_free()

	_pump_requests()
	_update_status()


func _apply_tile_bytes(key: String, bytes: PackedByteArray) -> bool:
	if not _tile_nodes.has(key):
		return false

	var image := Image.new()
	var error := image.load_png_from_buffer(bytes)
	if error != OK:
		return false

	var tile: TextureRect = _tile_nodes[key]
	if not is_instance_valid(tile):
		return false

	tile.texture = ImageTexture.create_from_image(image)
	return true


func _read_file_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


func _write_file_bytes(path: String, bytes: PackedByteArray) -> void:
	var absolute_dir := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()


func _cache_path(z: int, x: int, y: int) -> String:
	return "%s/%d/%d/%d.png" % [TILE_CACHE_ROOT, z, x, y]


func _tile_key(z: int, x: int, y: int) -> String:
	return "%d/%d/%d" % [z, x, y]


func _clamp_center() -> void:
	var north_west := _geo_to_world(REGION_WEST, REGION_NORTH, _zoom)
	var south_east := _geo_to_world(REGION_EAST, REGION_SOUTH, _zoom)

	var min_x := minf(north_west.x, south_east.x)
	var max_x := maxf(north_west.x, south_east.x)
	var min_y := minf(north_west.y, south_east.y)
	var max_y := maxf(north_west.y, south_east.y)
	var half := map_viewport.size * 0.5

	if max_x - min_x <= map_viewport.size.x:
		_center_world.x = (min_x + max_x) * 0.5
	else:
		_center_world.x = clampf(_center_world.x, min_x + half.x, max_x - half.x)

	if max_y - min_y <= map_viewport.size.y:
		_center_world.y = (min_y + max_y) * 0.5
	else:
		_center_world.y = clampf(_center_world.y, min_y + half.y, max_y - half.y)


func _geo_to_world(lon: float, lat: float, zoom: int) -> Vector2:
	var safe_lat := clampf(lat, -85.05112878, 85.05112878)
	var scale := TILE_SIZE * pow(2.0, float(zoom))
	var x := (lon + 180.0) / 360.0 * scale
	var lat_rad := deg_to_rad(safe_lat)
	var mercator := log(tan(lat_rad) + 1.0 / cos(lat_rad))
	var y := (1.0 - mercator / PI) * 0.5 * scale
	return Vector2(x, y)


func _world_to_geo(world: Vector2, zoom: int) -> Vector2:
	var scale := TILE_SIZE * pow(2.0, float(zoom))
	var lon := world.x / scale * 360.0 - 180.0
	var normalized_y := world.y / scale
	var mercator := PI * (1.0 - 2.0 * normalized_y)
	var lat := rad_to_deg(atan(sinh(mercator)))
	return Vector2(lon, lat)


func _update_status() -> void:
	zoom_label.text = "ZOOM %d / %d" % [_zoom, MAX_ZOOM]
	var loading := _active_requests + _pending_tiles.size()
	if loading > 0:
		status_label.text = "LOADING %d TILES" % loading
	elif _request_failures > 0:
		status_label.text = "MAP READY • %d NETWORK ERRORS" % _request_failures
	else:
		status_label.text = "MAP READY"


func _on_zoom_in_pressed() -> void:
	_set_zoom(_zoom + 1)


func _on_zoom_out_pressed() -> void:
	_set_zoom(_zoom - 1)


func _on_reset_pressed() -> void:
	_zoom = _best_fit_zoom()
	var center_lon := (REGION_WEST + REGION_EAST) * 0.5
	var center_lat := (REGION_NORTH + REGION_SOUTH) * 0.5
	_center_world = _geo_to_world(center_lon, center_lat, _zoom)
	_pending_tiles.clear()
	_queued_keys.clear()
	_refresh_tiles()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
