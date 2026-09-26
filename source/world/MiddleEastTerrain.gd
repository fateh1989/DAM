extends Node3D

# DAM world prototype:
# MAP = Syria strategic geography with accurate governorate/city anchors.
# TERRAIN = an art-directed RTS battlefield. Real DEM/OSM terrain is no longer
# a requirement. Terrain, roads, vegetation and local settlements are designed
# for gameplay and visual quality; only strategic locations/distances stay real.

const PROVINCE_CLOCK_SCRIPT := preload("res://source/world/ProvinceClock.gd")

const MIN_MAP_ZOOM := 4
const MAX_MAP_ZOOM := 10
const DEFAULT_MAP_ZOOM := 9
const ZOOM_WHEEL_MIN := 6
const ZOOM_WHEEL_MAX := 10
const SYRIA_OVERVIEW_ZOOM := 6
const STRATEGIC_GRID := 96
const STRATEGIC_CAMERA_MARGIN := 1.18
const STRATEGIC_RELIEF_EXAGGERATION := 6.0
const STRATEGIC_MAX_HEIGHT_M := 4000.0
const STRATEGIC_MACRO_PATH := "res://source/world/generated/syria_macro.png"
const STRATEGIC_VARIATION_PATH := "res://source/world/generated/syria_macro_variation.png"
const STRATEGIC_HEIGHT_PATH := "res://source/world/generated/syria_macro_height.png"
const STRATEGIC_SHADER_PATH := "res://source/world/shaders/StrategicMacro.gdshader"
const STRATEGIC_OVERLAY_PATH := "res://source/world/generated/syria_geo_overlay.json"
const TACTICAL_SHADER_PATH := "res://source/world/shaders/TacticalGround.gdshader"
const PROVINCE_LANDMARK_SCRIPT := preload("res://source/world/ProvinceLandmark.gd")

const PROVINCE_LANDMARKS := [
	{"governorate_index":0,"name_ar":"الجامع الأموي","name_en":"Umayyad Mosque","kind":"mosque","lat":33.5115,"lon":36.3067},
	{"governorate_index":1,"name_ar":"معلولا","name_en":"Maaloula","kind":"village","lat":33.8442,"lon":36.5460},
	{"governorate_index":2,"name_ar":"قلعة حلب","name_en":"Citadel of Aleppo","kind":"citadel","lat":36.1997,"lon":37.1629},
	{"governorate_index":3,"name_ar":"آثار تدمر","name_en":"Palmyra Ruins","kind":"ruins","lat":34.5503,"lon":38.2681},
	{"governorate_index":4,"name_ar":"نواعير حماة","name_en":"Norias of Hama","kind":"noria","lat":35.1340,"lon":36.7520},
	{"governorate_index":5,"name_ar":"قلعة صلاح الدين","name_en":"Saladin Castle","kind":"castle","lat":35.5956,"lon":36.0561},
	{"governorate_index":6,"name_ar":"قلعة أرواد","name_en":"Arwad Citadel","kind":"citadel","lat":34.8565,"lon":35.8588},
	{"governorate_index":7,"name_ar":"قلب لوزة","name_en":"Qalb Lozeh","kind":"ruins","lat":36.1670,"lon":36.5810},
	{"governorate_index":8,"name_ar":"باب بغداد","name_en":"Baghdad Gate","kind":"gate","lat":35.9505,"lon":39.0100},
	{"governorate_index":9,"name_ar":"الجسر المعلق","name_en":"Deir ez-Zor Suspension Bridge","kind":"bridge","lat":35.3374,"lon":40.1471},
	{"governorate_index":10,"name_ar":"تل حلف","name_en":"Tell Halaf","kind":"ruins","lat":36.8210,"lon":40.0390},
	{"governorate_index":11,"name_ar":"مسرح بصرى","name_en":"Bosra Roman Theatre","kind":"theatre","lat":32.5185,"lon":36.4812},
	{"governorate_index":12,"name_ar":"مسرح شهبا","name_en":"Shahba Roman Theatre","kind":"theatre","lat":32.8558,"lon":36.6284},
	{"governorate_index":13,"name_ar":"القنيطرة القديمة","name_en":"Old Quneitra","kind":"ruins","lat":33.1259,"lon":35.8246},
]
const TACTICAL_RELIEF_EXAGGERATION := 1.0
const TACTICAL_OVERVIEW_ZOOM := 8
const TACTICAL_OVERVIEW_RELIEF_EXAGGERATION := 60.0
const RTS_ZOOM_LEVEL_MIN := 1
const RTS_ZOOM_LEVEL_MAX := 8
const RTS_ZOOM_NEAR_DISTANCE_SCALE := 0.50
const RTS_ZOOM_FAR_DISTANCE_SCALE := 1.0
const RTS_ZOOM_DISTANCE_SCALES := [12.0, 6.5, 3.5, 1.9, 1.05, 0.72, 0.52, 0.40]
const RTS_CAMERA_HEIGHTS := [180.0, 105.0, 58.0, 30.0, 15.0, 8.5, 4.5, 2.35]
const RTS_CAMERA_BACKS := [220.0, 130.0, 72.0, 38.0, 20.0, 11.0, 5.8, 3.05]
const RTS_MARKER_SCALES := [0.24, 0.14, 0.075]
const RTS_DETAIL_UNIT_LOD_MIN := 6
const CONTINUOUS_MACRO_GRID := 36
const GROUP_FORMATION_SPACING_KM := 0.035
const HEAVY_FORCE_TEMPLATE := {
	"tank": 50,
	"rocket_launcher": 20,
	"artillery": 30,
}
const UNIT_SPEED_KM_PER_SEC := 0.60
const GOVERNORORATE_TANK_SEED := 14
const UNIT_SELECT_RADIUS_PX := 54.0
const TAP_MAX_DRAG_PX := 18.0
const ART_ROAD_WIDTH_KM := 0.090
const ART_ROAD_SHOULDER_KM := 0.145
const ART_CREEK_WIDTH_KM := 0.060

const TERRAIN_ZOOM := 13
const TERRAIN_TILE_RADIUS := 1
const MAP_TILE_RADIUS := 2
const KEEP_EXTRA := 1
const MAX_PARALLEL_REQUESTS := 5

const MAP_TILE_URL := "https://tile.openstreetmap.org/%d/%d/%d.png"
const DEM_TILE_URL := "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png"
const GOVERNORATES := [
	{"slug":"damascus","name_ar":"دمشق","name_en":"Damascus","lat":33.51019814679501,"lon":36.29127502441406},
	{"slug":"rif_dimashq","name_ar":"ريف دمشق / دوما","name_en":"Rif Dimashq / Douma","lat":33.571747,"lon":36.402701},
	{"slug":"aleppo","name_ar":"حلب","name_en":"Aleppo","lat":36.201241,"lon":37.161173},
	{"slug":"homs","name_ar":"حمص","name_en":"Homs","lat":34.72405042,"lon":36.72558878},
	{"slug":"hama","name_ar":"حماة","name_en":"Hama","lat":35.13179,"lon":36.757834},
	{"slug":"latakia","name_ar":"اللاذقية","name_en":"Latakia","lat":35.53124956,"lon":35.79088351},
	{"slug":"tartus","name_ar":"طرطوس","name_en":"Tartus","lat":34.889022,"lon":35.886586},
	{"slug":"idlib","name_ar":"إدلب","name_en":"Idlib","lat":35.930616,"lon":36.63393},
	{"slug":"raqqa","name_ar":"الرقة","name_en":"Raqqa","lat":35.952829,"lon":39.007879},
	{"slug":"deir_ez_zor","name_ar":"دير الزور","name_en":"Deir ez-Zor","lat":35.335876,"lon":40.140844},
	{"slug":"hasakah","name_ar":"الحسكة","name_en":"Al-Hasakah","lat":36.502368,"lon":40.747716},
	{"slug":"daraa","name_ar":"درعا","name_en":"Daraa","lat":32.618889,"lon":36.102134},
	{"slug":"suwayda","name_ar":"السويداء","name_en":"As-Suwayda","lat":32.708958,"lon":36.569513},
	{"slug":"quneitra","name_ar":"القنيطرة","name_en":"Quneitra","lat":33.125945,"lon":35.824613},
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
@onready var geo_overlay_button: Button = $HUD/GeoOverlayButton
@onready var governorate_label: Label = $HUD/GovernorateBar/Row/GovernorateLabel
@onready var zoom_wheel: VSlider = $HUD/ZoomWheel/Column/Slider
@onready var rts_radar: Control = $HUD/RTSRadar
@onready var province_clock_grid: GridContainer = $HUD/ProvinceClockPanel/Grid
@onready var selection_box: ColorRect = $HUD/SelectionBox

var _terrain_mode := true
var _map_zoom := MAX_MAP_ZOOM
var _map_zoom_before_terrain := MAX_MAP_ZOOM
var _rts_zoom_level := RTS_ZOOM_LEVEL_MIN
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
var _army_core = null
var _strategic_node: MeshInstance3D = null
var _continuous_macro_node: MeshInstance3D = null
var _strategic_material: ShaderMaterial = null
var _tactical_ground_material: ShaderMaterial = null
var _strategic_height_image: Image = null

var _geo_overlay_root: Node3D = null
var _geo_overlay_data: Dictionary = {}
var _geo_overlay_enabled := true
var _last_geo_overlay_origin := Vector2(999.0, 999.0)
var _last_geo_overlay_zoom := -1
var _geo_overlay_boundary_count := 0
var _geo_overlay_label_count := 0

var _unit_root: Node3D = null
var _units: Array = []
var _detail_unit_root: Node3D = null
var _detail_unit_nodes: Array[Node3D] = []
var _detail_governorate_index := -1
var _selected_unit_index := -1
var _selected_unit_indices: Array[int] = []
var _selected_logical_unit_ids: Array[String] = []
var _touch_press_positions := {}
var _touch_drag_distance := {}
var _multi_touch_gesture_active := false
var _mouse_press_position := Vector2.ZERO
var _mouse_drag_distance := 0.0
var _box_select_mode := false
var _box_select_active := false
var _box_select_pointer_id := -1
var _box_select_start := Vector2.ZERO
var _box_select_current := Vector2.ZERO
var _radar_action_mode := "camera"
var _move_order_serial := 0
var _province_clocks: Array[Control] = []
var _governorate_military_status: Array[Dictionary] = []
var _governorate_attack_state: Array[bool] = []
var _landmark_root: Node3D = null
var _landmarks: Array[Node3D] = []


func _ensure_province_clock_state() -> void:
	while _governorate_military_status.size() < GOVERNORATES.size():
		_governorate_military_status.append({"strength": 0.5, "readiness": 0.5})
	while _governorate_attack_state.size() < GOVERNORATES.size():
		_governorate_attack_state.append(false)


func _setup_province_clocks() -> void:
	_ensure_province_clock_state()
	_province_clocks.clear()
	for child in province_clock_grid.get_children():
		child.free()
	for i in range(GOVERNORATES.size()):
		var clock := PROVINCE_CLOCK_SCRIPT.new()
		clock.name = "ProvinceClock_%02d" % i
		province_clock_grid.add_child(clock)
		clock.setup(i, str(GOVERNORATES[i].get("name_ar", GOVERNORATES[i].get("name_en", ""))))
		clock.province_requested.connect(focus_governorate_from_clock)
		_province_clocks.append(clock)
		_sync_province_clock(i)


func _sync_province_clock(index: int) -> void:
	if index < 0 or index >= _province_clocks.size():
		return
	_ensure_province_clock_state()
	var clock: Control = _province_clocks[index]
	if not is_instance_valid(clock):
		return
	var status: Dictionary = _governorate_military_status[index]
	clock.call("set_military_status", float(status.get("strength", 0.5)), float(status.get("readiness", 0.5)))
	clock.call("set_attacking_state", bool(_governorate_attack_state[index]))
	clock.call("set_selected_state", index == _governorate_index)


func _sync_province_clock_selection() -> void:
	for i in range(_province_clocks.size()):
		_sync_province_clock(i)


func get_province_clocks() -> Array[Control]:
	return _province_clocks.duplicate()


func set_governorate_military_status(index: int, strength_value: float, readiness_value: float) -> bool:
	if index < 0 or index >= GOVERNORATES.size():
		return false
	_ensure_province_clock_state()
	_governorate_military_status[index] = {
		"strength": clampf(strength_value, 0.0, 1.0),
		"readiness": clampf(readiness_value, 0.0, 1.0),
	}
	_sync_province_clock(index)
	return true


func set_governorate_attack_state(index: int, value: bool) -> bool:
	if index < 0 or index >= GOVERNORATES.size():
		return false
	_ensure_province_clock_state()
	_governorate_attack_state[index] = value
	_sync_province_clock(index)
	return true


func get_governorate_military_status(index: int) -> Dictionary:
	if index < 0 or index >= GOVERNORATES.size():
		return {}
	_ensure_province_clock_state()
	var result: Dictionary = _governorate_military_status[index].duplicate()
	result["attacking"] = bool(_governorate_attack_state[index])
	return result


func _setup_landmarks() -> void:
	if _landmark_root == null or not is_instance_valid(_landmark_root):
		_landmark_root = Node3D.new()
		_landmark_root.name = "ProvinceLandmarks"
		add_child(_landmark_root)
	for child in _landmark_root.get_children():
		child.free()
	_landmarks.clear()
	for data in PROVINCE_LANDMARKS:
		var item := PROVINCE_LANDMARK_SCRIPT.new()
		item.name = "Landmark_%02d" % int(data["governorate_index"])
		_landmark_root.add_child(item)
		item.setup(
			int(data["governorate_index"]),
			str(data["name_ar"]),
			str(data["name_en"]),
			str(data["kind"])
		)
		_landmarks.append(item)
	_sync_landmark_positions()


func _sync_landmark_positions() -> void:
	if _landmark_root == null or not is_instance_valid(_landmark_root):
		return
	_landmark_root.visible = _terrain_mode
	for i in range(mini(_landmarks.size(), PROVINCE_LANDMARKS.size())):
		var item: Node3D = _landmarks[i]
		if not is_instance_valid(item):
			continue
		var data: Dictionary = PROVINCE_LANDMARKS[i]
		var lon := float(data["lon"])
		var lat := float(data["lat"])
		var height_km := _designed_height_m(lon, lat) / 1000.0 + 0.02
		item.position = _geo_to_local(lon, lat, height_km)
	_sync_landmark_selection()
	_sync_landmark_lod()
	_sync_landmark_labels()


func _landmark_visibility_radius_km() -> float:
	match _rts_zoom_level:
		1: return 220.0
		2: return 175.0
		3: return 135.0
		4: return 105.0
		_: return 82.0


func _sync_landmark_lod() -> void:
	var lod := 2 if _rts_zoom_level >= 3 else 1
	var radius_km := _landmark_visibility_radius_km()
	for item in _landmarks:
		if not is_instance_valid(item):
			continue
		if item.has_method("set_lod"):
			item.call("set_lod", lod)
		var province_index := int(item.get("governorate_index"))
		var is_focused := province_index == _governorate_index
		var local_distance := Vector2(item.position.x, item.position.z).length()
		item.visible = _terrain_mode and (is_focused or local_distance <= radius_km)


func get_visible_landmark_count() -> int:
	var count := 0
	for item in _landmarks:
		if is_instance_valid(item) and item.visible:
			count += 1
	return count


func _sync_landmark_selection() -> void:
	for item in _landmarks:
		if is_instance_valid(item) and item.has_method("set_selected"):
			item.call("set_selected", int(item.get("governorate_index")) == _governorate_index)


func _sync_landmark_labels() -> void:
	var show_labels := _terrain_mode and _rts_zoom_level >= 3
	for item in _landmarks:
		if is_instance_valid(item) and item.has_method("set_label_visible"):
			item.call("set_label_visible", show_labels)


func get_province_landmarks() -> Array[Node3D]:
	return _landmarks.duplicate()


func validate_province_landmark_catalog() -> String:
	if PROVINCE_LANDMARKS.size() != GOVERNORATES.size():
		return "landmark count does not match governorate count"
	var seen := {}
	for i in range(PROVINCE_LANDMARKS.size()):
		var data: Dictionary = PROVINCE_LANDMARKS[i]
		var governorate_index := int(data.get("governorate_index", -1))
		if governorate_index != i:
			return "landmark governorate order is inconsistent"
		if seen.has(governorate_index):
			return "duplicate governorate landmark"
		seen[governorate_index] = true
		if str(data.get("name_ar", "")).is_empty() or str(data.get("name_en", "")).is_empty():
			return "landmark name is missing"
		var lon := float(data.get("lon", 999.0))
		var lat := float(data.get("lat", 999.0))
		if lon < REGION_WEST or lon > REGION_EAST or lat < REGION_SOUTH or lat > REGION_NORTH:
			return "landmark coordinates are outside Syria world bounds"
	return ""


func _game_state_node() -> Node:
	return get_node_or_null("/root/GameState")


func _audio_focus_node() -> Node:
	return get_node_or_null("/root/AudioFocusManager")


func _ready() -> void:
	if ClassDB.class_exists("DAMNativeCore"):
		_native_core = ClassDB.instantiate("DAMNativeCore")
	_setup_army_combat_core()
	_setup_environment()
	_setup_province_clocks()
	_origin_lon = _center_lon
	_origin_lat = _center_lat
	_setup_landmarks()
	_update_governorate_ui()
	zoom_wheel.set_value_no_signal(float(_rts_zoom_level if _terrain_mode else _map_zoom))
	zoom_wheel.visible = _terrain_mode
	_setup_unit_layer()
	_setup_geo_overlay_layer()
	_build_continuous_macro_world()
	_position_camera()
	_refresh_tiles()
	_sync_continuous_world_lod()
	_sync_unit_visuals()
	_sync_detail_unit_lod()
	_refresh_geo_overlay(true)
	_bind_audio_controls()
	_update_radar_mode_ui()
	_update_status()


func _bind_audio_controls() -> void:
	for path in [
		"HUD/TopBar/Row/BackButton",
		"HUD/TopBar/Row/ResetButton",
		"HUD/TopBar/Row/ZoomOutButton",
		"HUD/TopBar/Row/ZoomInButton",
		"HUD/ModeButton",
		"HUD/GeoOverlayButton",
		"HUD/GovernorateBar/Row/PreviousButton",
		"HUD/GovernorateBar/Row/NextButton",
		"HUD/CommandBar/Row/SelectAllUnitsButton",
		"HUD/CommandBar/Row/ClearSelectionButton",
		"HUD/CommandBar/Row/PreviousUnitButton",
		"HUD/CommandBar/Row/NextUnitButton",
		"HUD/CommandBar/Row/FocusUnitsButton",
		"HUD/CommandBar/Row/StopUnitsButton",
		"HUD/CommandBar/Row/RadarModeButton",
	]:
		var control := get_node_or_null(path) as Control
		if control != null:
			var audio := _audio_focus_node()
			if audio != null:
				audio.call("bind_control", control, "ui")


func _focus_world_audio(screen_position: Vector2) -> void:
	if _units.is_empty():
		var audio := _audio_focus_node()
		if audio != null:
			audio.call("clear_focus")
		return

	var closest_index := -1
	var closest_distance := UNIT_SELECT_RADIUS_PX
	for i in range(_units.size()):
		var unit: Dictionary = _units[i]
		if not bool(unit.get("alive", true)):
			continue
		var node = unit.get("node")
		if not (node is Node3D):
			continue
		if not is_instance_valid(node) or camera.is_position_behind(node.global_position):
			continue
		var distance := camera.unproject_position(node.global_position).distance_to(screen_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = i

	if closest_index >= 0:
		var audio := _audio_focus_node()
		if audio != null:
			audio.call("focus_object", "strategic:unit:%d" % closest_index, "friendly_tank")
	else:
		var audio := _audio_focus_node()
		if audio != null:
			audio.call("clear_focus")


func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.19, 0.28, 0.34, 1.0)
	environment.background_energy_multiplier = 0.72
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.70, 0.68, 0.58, 1.0)
	environment.ambient_light_energy = 0.58
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.88
	world_environment.environment = environment


func _should_accept_world_tap(active_touch_count: int, drag_distance: float) -> bool:
	return active_touch_count == 1 and not _multi_touch_gesture_active and drag_distance <= TAP_MAX_DRAG_PX


func _begin_box_selection(pointer_id: int, screen_position: Vector2) -> void:
	_box_select_active = true
	_box_select_pointer_id = pointer_id
	_box_select_start = screen_position
	_box_select_current = screen_position
	if selection_box != null:
		selection_box.position = screen_position
		selection_box.size = Vector2.ZERO
		selection_box.visible = true


func _update_box_selection(screen_position: Vector2) -> void:
	if not _box_select_active:
		return
	_box_select_current = screen_position
	var rect := Rect2(_box_select_start, _box_select_current - _box_select_start).abs()
	if selection_box != null:
		selection_box.position = rect.position
		selection_box.size = rect.size
		selection_box.visible = true


func _finish_box_selection(screen_position: Vector2) -> int:
	if not _box_select_active:
		return 0
	_update_box_selection(screen_position)
	var rect := Rect2(_box_select_start, _box_select_current - _box_select_start).abs()
	var selected_count := 0
	if rect.size.length() > TAP_MAX_DRAG_PX:
		selected_count = select_logical_heavy_units_in_screen_rect(rect, false)
	else:
		_handle_world_tap(screen_position)
		selected_count = get_selected_logical_heavy_count()
	_box_select_active = false
	_box_select_pointer_id = -1
	_box_select_mode = false
	if selection_box != null:
		selection_box.visible = false
	var button := get_node_or_null("HUD/CommandBar/Row/BoxSelectButton") as Button
	if button != null:
		button.text = "BOX SELECT"
	_update_status()
	return selected_count


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _box_select_mode and not _box_select_active:
			_focus_world_audio(event.position)
			_touches[event.index] = event.position
			_touch_press_positions[event.index] = event.position
			_touch_drag_distance[event.index] = 0.0
			_begin_box_selection(event.index, event.position)
			get_viewport().set_input_as_handled()
			return
		if not event.pressed and _box_select_active and event.index == _box_select_pointer_id:
			_finish_box_selection(event.position)
			_touches.erase(event.index)
			_touch_press_positions.erase(event.index)
			_touch_drag_distance.erase(event.index)
			if _touches.is_empty():
				_multi_touch_gesture_active = false
			_pinch_accumulator = 0.0
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			_focus_world_audio(event.position)
			_touches[event.index] = event.position
			_touch_press_positions[event.index] = event.position
			_touch_drag_distance[event.index] = 0.0
			if _touches.size() > 1:
				_multi_touch_gesture_active = true
		else:
			var drag_distance := float(_touch_drag_distance.get(event.index, 9999.0))
			if _should_accept_world_tap(_touches.size(), drag_distance):
				_handle_world_tap(event.position)
			_touches.erase(event.index)
			_touch_press_positions.erase(event.index)
			_touch_drag_distance.erase(event.index)
			if _touches.is_empty():
				_multi_touch_gesture_active = false
		_pinch_accumulator = 0.0
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		if _box_select_active and event.index == _box_select_pointer_id:
			_touches[event.index] = event.position
			_touch_drag_distance[event.index] = float(_touch_drag_distance.get(event.index, 0.0)) + event.relative.length()
			_update_box_selection(event.position)
			get_viewport().set_input_as_handled()
			return
		if not _touches.has(event.index):
			_touches[event.index] = event.position - event.relative
			_touch_press_positions[event.index] = event.position - event.relative
			_touch_drag_distance[event.index] = 0.0

		_touch_drag_distance[event.index] = float(_touch_drag_distance.get(event.index, 0.0)) + event.relative.length()

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
				_set_rts_zoom_level(_rts_zoom_level + (1 if _pinch_accumulator > 0.0 else -1))
				_pinch_accumulator = 0.0

		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _box_select_mode and not _box_select_active:
				_mouse_dragging = false
				_mouse_press_position = event.position
				_mouse_drag_distance = 0.0
				_begin_box_selection(-1, event.position)
			elif not event.pressed and _box_select_active and _box_select_pointer_id == -1:
				_finish_box_selection(event.position)
				_mouse_dragging = false
			elif event.pressed:
				_mouse_dragging = true
				_mouse_press_position = event.position
				_mouse_drag_distance = 0.0
			else:
				_mouse_dragging = false
				if _mouse_drag_distance <= TAP_MAX_DRAG_PX:
					_handle_world_tap(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_rts_zoom_level(_rts_zoom_level + 1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_rts_zoom_level(_rts_zoom_level - 1)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _box_select_active and _box_select_pointer_id == -1:
		_mouse_drag_distance += event.relative.length()
		_update_box_selection(event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _mouse_dragging:
		_mouse_drag_distance += event.relative.length()
		_pan_from_screen_delta(event.relative)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		_focus_world_audio(event.position)

func _pan_from_screen_delta(delta: Vector2) -> void:
	var viewport_height := maxf(1.0, float(get_viewport().get_visible_rect().size.y))
	var km_per_pixel := 0.0

	if _terrain_mode and not _is_tactical_overview():
		km_per_pixel = 0.018 * _rts_camera_distance_scale()
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
	_sync_unit_visuals()
	_refresh_geo_overlay(false)

func get_rts_camera_distance_scale(level: int = _rts_zoom_level) -> float:
	var clamped_level := clampi(level, RTS_ZOOM_LEVEL_MIN, RTS_ZOOM_LEVEL_MAX)
	return float(RTS_ZOOM_DISTANCE_SCALES[clamped_level - RTS_ZOOM_LEVEL_MIN])


func _rts_camera_distance_scale() -> float:
	return get_rts_camera_distance_scale(_rts_zoom_level)


func get_rts_camera_profile(level: int = _rts_zoom_level) -> Dictionary:
	var clamped_level := clampi(level, RTS_ZOOM_LEVEL_MIN, RTS_ZOOM_LEVEL_MAX)
	var index := clamped_level - RTS_ZOOM_LEVEL_MIN
	var t := float(index) / float(RTS_ZOOM_LEVEL_MAX - RTS_ZOOM_LEVEL_MIN)
	return {
		"height": float(RTS_CAMERA_HEIGHTS[index]),
		"back": float(RTS_CAMERA_BACKS[index]),
		"look_y": lerpf(0.05, 0.22, t),
		"fov": lerpf(38.0, 45.0, t),
	}


func get_tactical_detail_profile(level: int = _rts_zoom_level) -> Dictionary:
	var clamped_level := clampi(level, RTS_ZOOM_LEVEL_MIN, RTS_ZOOM_LEVEL_MAX)
	var t := float(clamped_level - RTS_ZOOM_LEVEL_MIN) / float(RTS_ZOOM_LEVEL_MAX - RTS_ZOOM_LEVEL_MIN)
	return {
		"detail_lod": lerpf(0.25, 1.0, t),
		"slope_detail_strength": lerpf(0.45, 1.0, t),
		"macro_variation_strength": lerpf(1.25, 0.85, t),
		"micro_detail_strength": lerpf(0.25, 1.0, t),
	}


func _use_macro_world_lod(level: int = _rts_zoom_level) -> bool:
	return level <= 2


func _sync_continuous_world_lod() -> void:
	var use_macro := _use_macro_world_lod()
	if is_instance_valid(_continuous_macro_node):
		_continuous_macro_node.visible = use_macro
	for state_value in _tiles.values():
		var state: Dictionary = state_value
		var node = state.get("node")
		if node != null and is_instance_valid(node):
			node.visible = not use_macro
	if is_instance_valid(vector_root):
		vector_root.visible = not use_macro


func _sync_tactical_ground_detail() -> void:
	if _tactical_ground_material == null:
		return
	var profile := get_tactical_detail_profile()
	for key in profile.keys():
		_tactical_ground_material.set_shader_parameter(str(key), profile[key])


func _set_rts_zoom_level(new_level: int) -> void:
	new_level = clampi(new_level, RTS_ZOOM_LEVEL_MIN, RTS_ZOOM_LEVEL_MAX)
	if new_level == _rts_zoom_level:
		return
	_rts_zoom_level = new_level
	zoom_wheel.set_value_no_signal(float(_rts_zoom_level))
	_position_camera()
	_sync_tactical_ground_detail()
	_sync_continuous_world_lod()
	_sync_unit_visuals()
	_sync_detail_unit_lod()
	_refresh_geo_overlay(true)
	if _terrain_mode and not _is_tactical_overview() and _rts_zoom_level >= 4:
		call_deferred("_refresh_vector_data", true)
	_update_status()


func _set_map_zoom(new_zoom: int, center_syria_at_overview: bool = false) -> void:
	if _terrain_mode:
		return
	new_zoom = clampi(new_zoom, MIN_MAP_ZOOM, MAX_MAP_ZOOM)

	if center_syria_at_overview and new_zoom <= SYRIA_OVERVIEW_ZOOM:
		_center_lon = (REGION_WEST + REGION_EAST) * 0.5
		_center_lat = (REGION_SOUTH + REGION_NORTH) * 0.5

	var changed := new_zoom != _map_zoom
	_map_zoom = new_zoom
	zoom_wheel.set_value_no_signal(float(clampi(_map_zoom, ZOOM_WHEEL_MIN, ZOOM_WHEEL_MAX)))

	if not changed and not center_syria_at_overview:
		return

	if _terrain_mode:
		_clear_all_world_nodes()
	else:
		_clear_tiles()

	_position_camera()
	_refresh_tiles()
	if _terrain_mode and not _is_tactical_overview():
		call_deferred("_refresh_vector_data", true)
	_sync_unit_visuals()
	_refresh_geo_overlay(true)
	_update_status()

func _position_camera() -> void:
	_sync_landmark_positions()
	if _terrain_mode and _is_tactical_overview():
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		match _map_zoom:
			8:
				camera.size = 155.0
			7:
				camera.size = 305.0
			_:
				var syria_height_km := EARTH_RADIUS_KM * deg_to_rad(REGION_NORTH - REGION_SOUTH)
				camera.size = syria_height_km * STRATEGIC_CAMERA_MARGIN
		_clamp_overview_center_to_world()

	var center := _geo_to_local(_center_lon, _center_lat, 0.0)

	if _terrain_mode:
		if _is_tactical_overview():
			camera.position = center + Vector3(0.0, 500.0, 0.01)
			camera.look_at(center, Vector3(0.0, 0.0, -1.0))
			camera.near = 0.1
			camera.far = 1200.0
		else:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			var profile := get_rts_camera_profile()
			camera.position = center + Vector3(0.0, float(profile["height"]), float(profile["back"]))
			camera.look_at(center + Vector3(0.0, float(profile["look_y"]), 0.0), Vector3.UP)
			camera.fov = float(profile["fov"])
			camera.near = 0.01
			camera.far = 1200.0
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		if _is_strategic_map():
			var syria_height_km := EARTH_RADIUS_KM * deg_to_rad(REGION_NORTH - REGION_SOUTH)
			camera.size = syria_height_km * STRATEGIC_CAMERA_MARGIN
		else:
			camera.size = _map_tile_width_km() * 4.7
		camera.position = center + Vector3(0.0, 500.0, 0.01)
		camera.look_at(center, Vector3(0.0, 0.0, -1.0))
		camera.near = 0.1
		camera.far = 1000.0


func _clamp_overview_center_to_world() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var aspect := maxf(0.2, float(viewport.x) / maxf(1.0, float(viewport.y)))
	var half_height_km := camera.size * 0.5
	var half_width_km := camera.size * aspect * 0.5

	var half_lat_deg := rad_to_deg(half_height_km / EARTH_RADIUS_KM)
	var lon_radius := EARTH_RADIUS_KM * maxf(0.15, cos(deg_to_rad(_center_lat)))
	var half_lon_deg := rad_to_deg(half_width_km / lon_radius)

	var lat_span := REGION_NORTH - REGION_SOUTH
	var lon_span := REGION_EAST - REGION_WEST

	if half_lat_deg * 2.0 >= lat_span:
		_center_lat = (REGION_NORTH + REGION_SOUTH) * 0.5
	else:
		_center_lat = clampf(_center_lat, REGION_SOUTH + half_lat_deg, REGION_NORTH - half_lat_deg)

	if half_lon_deg * 2.0 >= lon_span:
		_center_lon = (REGION_EAST + REGION_WEST) * 0.5
	else:
		_center_lon = clampf(_center_lon, REGION_WEST + half_lon_deg, REGION_EAST - half_lon_deg)

func _is_strategic_map() -> bool:
	# DAM has one continuous RTS world; the legacy separate strategic-map path stays disabled.
	return false


func _is_tactical_overview() -> bool:
	# Far/near views are camera + LOD states inside the same RTS world.
	return false


func _refresh_tiles() -> void:
	if _is_tactical_overview():
		_pending.clear()
		_queued.clear()
		_required_keys.clear()
		_keep_keys.clear()
		_build_strategic_world()
		_update_status()
		return

	if _is_strategic_map():
		_pending.clear()
		_queued.clear()
		_required_keys.clear()
		_keep_keys.clear()
		_build_strategic_world()
		_update_status()
		return

	_clear_strategic_world()

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
	_sync_continuous_world_lod()
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

	# Draw immediately. Tactical terrain is generated locally and requires no
	# DEM or OSM network request. Map mode may still use cartographic tiles.
	_rebuild_tile(key)

	if _terrain_mode:
		return

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


func _global_terrain_uv(lon: float, lat: float) -> Vector2:
	return Vector2(
		clampf((lon - REGION_WEST) / (REGION_EAST - REGION_WEST), 0.0, 1.0),
		clampf((REGION_NORTH - lat) / (REGION_NORTH - REGION_SOUTH), 0.0, 1.0)
	)


func _designed_height_m(lon: float, lat: float) -> float:
	# Gameplay terrain, intentionally NOT real topography.
	# Geographic coordinates only keep the field deterministic and seamless.
	var x := lon * 18.0
	var y := lat * 18.0
	var broad := sin(x * 0.53 + y * 0.27) * 18.0
	broad += sin(x * 0.21 - y * 0.46 + 1.7) * 13.0
	var medium := sin(x * 1.23 + y * 0.91 + 0.8) * 7.0
	medium += sin(x * 1.77 - y * 1.31) * 5.0
	var basin := sin((x + y) * 0.10) * 8.0
	return maxf(2.0, 30.0 + broad + medium + basin)


func _designed_height_local(x_km: float, z_km: float) -> float:
	var lat := _origin_lat - rad_to_deg(z_km / EARTH_RADIUS_KM)
	var lon_radius := EARTH_RADIUS_KM * maxf(0.15, cos(deg_to_rad(_origin_lat)))
	var lon := _origin_lon + rad_to_deg(x_km / lon_radius)
	return _designed_height_m(lon, lat) / 1000.0


func _art_point(x_km: float, z_km: float, y_offset: float = 0.0) -> Vector3:
	return Vector3(x_km, _designed_height_local(x_km, z_km) + y_offset, z_km)


func _cell_vertex_height(
	z: int,
	x: int,
	y: int,
	u: float,
	v: float,
	elevation_m: float
) -> Vector3:
	var geo := _tile_fraction_to_lon_lat(z, x, y, u, v)
	var height_km := elevation_m / 1000.0 * TACTICAL_RELIEF_EXAGGERATION
	return _geo_to_local(geo.x, geo.y, height_km)


func _smooth_render_heights(raw: PackedFloat32Array) -> PackedFloat32Array:
	var result := raw.duplicate()
	var stride := CELL_GRID + 1

	# Smooth only interior vertices. Border samples remain untouched so
	# adjacent Terrarium tiles continue to meet at the same geographic edge.
	for gy in range(1, CELL_GRID):
		for gx in range(1, CELL_GRID):
			var center := gy * stride + gx
			var sum := raw[center] * 4.0
			sum += raw[center - 1] * 2.0
			sum += raw[center + 1] * 2.0
			sum += raw[center - stride] * 2.0
			sum += raw[center + stride] * 2.0
			sum += raw[center - stride - 1]
			sum += raw[center - stride + 1]
			sum += raw[center + stride - 1]
			sum += raw[center + stride + 1]
			result[center] = sum / 16.0

	return result


func _add_ground_triangle(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2
) -> void:
	st.set_uv(uv_a); st.add_vertex(a)
	st.set_uv(uv_b); st.add_vertex(b)
	st.set_uv(uv_c); st.add_vertex(c)


func _get_tactical_ground_material() -> ShaderMaterial:
	if _tactical_ground_material != null:
		return _tactical_ground_material

	var shader := load(TACTICAL_SHADER_PATH) as Shader
	if shader == null:
		push_error("DAM Tactical: art-directed ground shader is missing")
		return null

	_tactical_ground_material = ShaderMaterial.new()
	_tactical_ground_material.shader = shader
	_sync_tactical_ground_detail()
	return _tactical_ground_material


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

	# DEM remains authoritative. Rendering now uses a continuous floating
	# height field; the discrete 20 m grid remains only for analysis/gameplay.
	var raw_heights := PackedFloat32Array()
	raw_heights.resize((CELL_GRID + 1) * (CELL_GRID + 1))
	var levels := PackedInt32Array()
	levels.resize((CELL_GRID + 1) * (CELL_GRID + 1))

	for gy in range(CELL_GRID + 1):
		var v := float(gy) / float(CELL_GRID)
		for gx in range(CELL_GRID + 1):
			var u := float(gx) / float(CELL_GRID)
			var geo := _tile_fraction_to_lon_lat(z, x, y, u, v)
			var elevation_m := _designed_height_m(geo.x, geo.y)
			var sample_index := gy * (CELL_GRID + 1) + gx
			raw_heights[sample_index] = elevation_m
			levels[sample_index] = int(round(elevation_m / CELL_HEIGHT_STEP_M))

	var render_heights := _smooth_render_heights(raw_heights)

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

			var p00 := _cell_vertex_height(z, x, y, u0, v0, render_heights[i00])
			var p10 := _cell_vertex_height(z, x, y, u1, v0, render_heights[i10])
			var p01 := _cell_vertex_height(z, x, y, u0, v1, render_heights[i01])
			var p11 := _cell_vertex_height(z, x, y, u1, v1, render_heights[i11])

			var g00 := _tile_fraction_to_lon_lat(z, x, y, u0, v0)
			var g10 := _tile_fraction_to_lon_lat(z, x, y, u1, v0)
			var g01 := _tile_fraction_to_lon_lat(z, x, y, u0, v1)
			var g11 := _tile_fraction_to_lon_lat(z, x, y, u1, v1)

			var uv00 := _global_terrain_uv(g00.x, g00.y)
			var uv10 := _global_terrain_uv(g10.x, g10.y)
			var uv01 := _global_terrain_uv(g01.x, g01.y)
			var uv11 := _global_terrain_uv(g11.x, g11.y)

			_add_ground_triangle(st, p00, p01, p10, uv00, uv01, uv10)
			_add_ground_triangle(st, p10, p01, p11, uv10, uv01, uv11)

	# The old vertical cliff quads are intentionally not rendered in this pass.
	# They produced dark triangular artifacts. Cliff candidates remain in the
	# native analysis and will return later as a dedicated rock-mesh system.
	_cliff_face_count = 0

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
	node.material_override = _get_tactical_ground_material()
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

func _continuous_macro_color(height_m: float, lon: float, lat: float) -> Color:
	var dry_wave := 0.5 + 0.5 * sin(lon * 2.9 + lat * 1.7)
	if height_m >= 900.0:
		return Color(0.34, 0.31, 0.26, 1.0).lerp(Color(0.47, 0.42, 0.34, 1.0), dry_wave * 0.45)
	if height_m >= 450.0:
		return Color(0.45, 0.43, 0.28, 1.0).lerp(Color(0.55, 0.49, 0.31, 1.0), dry_wave * 0.35)
	if lat < 34.0:
		return Color(0.52, 0.43, 0.25, 1.0).lerp(Color(0.62, 0.52, 0.31, 1.0), dry_wave * 0.30)
	return Color(0.32, 0.40, 0.24, 1.0).lerp(Color(0.47, 0.44, 0.27, 1.0), dry_wave * 0.28)


func _build_continuous_macro_world() -> void:
	if is_instance_valid(_continuous_macro_node):
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for gy in range(CONTINUOUS_MACRO_GRID):
		var v0 := float(gy) / float(CONTINUOUS_MACRO_GRID)
		var v1 := float(gy + 1) / float(CONTINUOUS_MACRO_GRID)
		for gx in range(CONTINUOUS_MACRO_GRID):
			var u0 := float(gx) / float(CONTINUOUS_MACRO_GRID)
			var u1 := float(gx + 1) / float(CONTINUOUS_MACRO_GRID)
			var lon0 := lerpf(REGION_WEST, REGION_EAST, u0)
			var lon1 := lerpf(REGION_WEST, REGION_EAST, u1)
			var lat0 := lerpf(REGION_NORTH, REGION_SOUTH, v0)
			var lat1 := lerpf(REGION_NORTH, REGION_SOUTH, v1)
			var h00m := _designed_height_m(lon0, lat0)
			var h10m := _designed_height_m(lon1, lat0)
			var h01m := _designed_height_m(lon0, lat1)
			var h11m := _designed_height_m(lon1, lat1)
			var p00 := _geo_to_local(lon0, lat0, h00m / 1000.0)
			var p10 := _geo_to_local(lon1, lat0, h10m / 1000.0)
			var p01 := _geo_to_local(lon0, lat1, h01m / 1000.0)
			var p11 := _geo_to_local(lon1, lat1, h11m / 1000.0)
			st.set_color(_continuous_macro_color(h00m, lon0, lat0)); st.add_vertex(p00)
			st.set_color(_continuous_macro_color(h01m, lon0, lat1)); st.add_vertex(p01)
			st.set_color(_continuous_macro_color(h10m, lon1, lat0)); st.add_vertex(p10)
			st.set_color(_continuous_macro_color(h10m, lon1, lat0)); st.add_vertex(p10)
			st.set_color(_continuous_macro_color(h01m, lon0, lat1)); st.add_vertex(p01)
			st.set_color(_continuous_macro_color(h11m, lon1, lat1)); st.add_vertex(p11)
	st.generate_normals()
	var mesh := st.commit()
	if mesh == null:
		push_error("DAM continuous macro terrain build failed")
		return
	_continuous_macro_node = MeshInstance3D.new()
	_continuous_macro_node.name = "ContinuousWorldMacroLOD"
	_continuous_macro_node.mesh = mesh
	_continuous_macro_node.material_override = _make_vertex_color_material()
	_continuous_macro_node.visible = false
	terrain_root.add_child(_continuous_macro_node)


func _clear_strategic_world() -> void:
	if is_instance_valid(_strategic_node):
		_strategic_node.queue_free()
	_strategic_node = null
	_strategic_material = null


func _strategic_height_at(image: Image, u: float, v: float) -> float:
	if image == null or image.is_empty():
		return 0.0
	var px := clampi(int(round(u * float(image.get_width() - 1))), 0, image.get_width() - 1)
	var py := clampi(int(round(v * float(image.get_height() - 1))), 0, image.get_height() - 1)
	return clampf(image.get_pixel(px, py).r * STRATEGIC_MAX_HEIGHT_M, 0.0, STRATEGIC_MAX_HEIGHT_M)


func _build_strategic_world() -> void:
	if is_instance_valid(_strategic_node):
		return

	var macro_texture := load(STRATEGIC_MACRO_PATH) as Texture2D
	var variation_texture := load(STRATEGIC_VARIATION_PATH) as Texture2D
	var height_texture := load(STRATEGIC_HEIGHT_PATH) as Texture2D
	var strategic_shader := load(STRATEGIC_SHADER_PATH) as Shader

	if macro_texture == null or variation_texture == null or height_texture == null or strategic_shader == null:
		push_error("DAM Strategic: generated macro assets are missing")
		return

	_strategic_height_image = height_texture.get_image()
	if _strategic_height_image == null or _strategic_height_image.is_empty():
		push_error("DAM Strategic: macro height image is unreadable")
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_color := Color("#A69258")

	for gy in range(STRATEGIC_GRID):
		var v0 := float(gy) / float(STRATEGIC_GRID)
		var v1 := float(gy + 1) / float(STRATEGIC_GRID)
		for gx in range(STRATEGIC_GRID):
			var u0 := float(gx) / float(STRATEGIC_GRID)
			var u1 := float(gx + 1) / float(STRATEGIC_GRID)

			var lon0 := lerpf(REGION_WEST, REGION_EAST, u0)
			var lon1 := lerpf(REGION_WEST, REGION_EAST, u1)
			var lat0 := lerpf(REGION_NORTH, REGION_SOUTH, v0)
			var lat1 := lerpf(REGION_NORTH, REGION_SOUTH, v1)

			var h00 := _strategic_height_at(_strategic_height_image, u0, v0) / 1000.0 * STRATEGIC_RELIEF_EXAGGERATION
			var h10 := _strategic_height_at(_strategic_height_image, u1, v0) / 1000.0 * STRATEGIC_RELIEF_EXAGGERATION
			var h01 := _strategic_height_at(_strategic_height_image, u0, v1) / 1000.0 * STRATEGIC_RELIEF_EXAGGERATION
			var h11 := _strategic_height_at(_strategic_height_image, u1, v1) / 1000.0 * STRATEGIC_RELIEF_EXAGGERATION

			var p00 := _geo_to_local(lon0, lat0, h00)
			var p10 := _geo_to_local(lon1, lat0, h10)
			var p01 := _geo_to_local(lon0, lat1, h01)
			var p11 := _geo_to_local(lon1, lat1, h11)

			st.set_color(base_color); st.set_uv(Vector2(u0, v0)); st.add_vertex(p00)
			st.set_color(base_color); st.set_uv(Vector2(u0, v1)); st.add_vertex(p01)
			st.set_color(base_color); st.set_uv(Vector2(u1, v0)); st.add_vertex(p10)

			st.set_color(base_color); st.set_uv(Vector2(u1, v0)); st.add_vertex(p10)
			st.set_color(base_color); st.set_uv(Vector2(u0, v1)); st.add_vertex(p01)
			st.set_color(base_color); st.set_uv(Vector2(u1, v1)); st.add_vertex(p11)

	st.generate_normals()
	var mesh := st.commit()
	if mesh == null:
		push_error("DAM Strategic: failed to build Syria macro mesh")
		return

	_strategic_node = MeshInstance3D.new()
	_strategic_node.name = "RTSSyriaOverview" if _terrain_mode else "StrategicSyriaMacro"
	_strategic_node.mesh = mesh
	terrain_root.add_child(_strategic_node)

	_strategic_material = ShaderMaterial.new()
	_strategic_material.shader = strategic_shader
	_strategic_material.set_shader_parameter("global_macro_tex", macro_texture)
	_strategic_material.set_shader_parameter("macro_variation", variation_texture)

	var nw := _geo_to_local(REGION_WEST, REGION_NORTH, 0.0)
	var se := _geo_to_local(REGION_EAST, REGION_SOUTH, 0.0)
	var origin_m := Vector2(nw.x, nw.z) * 1000.0
	var size_m := Vector2(se.x - nw.x, se.z - nw.z) * 1000.0
	_strategic_material.set_shader_parameter("world_origin", origin_m)
	_strategic_material.set_shader_parameter("world_size_meters", size_m)
	_strategic_material.set_shader_parameter("detail_fade_start_m", 0.0 if _terrain_mode else 60000.0)
	_strategic_material.set_shader_parameter("detail_fade_end_m", 1.0 if _terrain_mode else 220000.0)

	_strategic_node.material_override = _strategic_material

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


func _append_art_box(
	st: SurfaceTool,
	center: Vector3,
	size_x: float,
	size_z: float,
	height: float
) -> void:
	var x0 := center.x - size_x * 0.5
	var x1 := center.x + size_x * 0.5
	var z0 := center.z - size_z * 0.5
	var z1 := center.z + size_z * 0.5
	var y0 := center.y
	var y1 := center.y + height
	var b0 := Vector3(x0, y0, z0)
	var b1 := Vector3(x1, y0, z0)
	var b2 := Vector3(x1, y0, z1)
	var b3 := Vector3(x0, y0, z1)
	var t0 := Vector3(x0, y1, z0)
	var t1 := Vector3(x1, y1, z0)
	var t2 := Vector3(x1, y1, z1)
	var t3 := Vector3(x0, y1, z1)

	# Four walls + flat roof.
	st.add_vertex(b0); st.add_vertex(b1); st.add_vertex(t0)
	st.add_vertex(t0); st.add_vertex(b1); st.add_vertex(t1)
	st.add_vertex(b1); st.add_vertex(b2); st.add_vertex(t1)
	st.add_vertex(t1); st.add_vertex(b2); st.add_vertex(t2)
	st.add_vertex(b2); st.add_vertex(b3); st.add_vertex(t2)
	st.add_vertex(t2); st.add_vertex(b3); st.add_vertex(t3)
	st.add_vertex(b3); st.add_vertex(b0); st.add_vertex(t3)
	st.add_vertex(t3); st.add_vertex(b0); st.add_vertex(t0)
	st.add_vertex(t0); st.add_vertex(t1); st.add_vertex(t2)
	st.add_vertex(t0); st.add_vertex(t2); st.add_vertex(t3)


func _build_art_directed_battlefield() -> void:
	_clear_vector_nodes()

	var shoulders := SurfaceTool.new()
	var roads := SurfaceTool.new()
	var creek_bank := SurfaceTool.new()
	var creek := SurfaceTool.new()
	var buildings := SurfaceTool.new()
	shoulders.begin(Mesh.PRIMITIVE_TRIANGLES)
	roads.begin(Mesh.PRIMITIVE_TRIANGLES)
	creek_bank.begin(Mesh.PRIMITIVE_TRIANGLES)
	creek.begin(Mesh.PRIMITIVE_TRIANGLES)
	buildings.begin(Mesh.PRIMITIVE_TRIANGLES)

	var main_road: Array[Vector3] = []
	var cross_road: Array[Vector3] = []
	var river: Array[Vector3] = []

	for i in range(19):
		var x := -6.3 + float(i) * 0.70
		main_road.append(_art_point(x, sin(x * 0.55) * 0.90 - 0.35, 0.018))
		var z := -5.5 + float(i) * 0.62
		cross_road.append(_art_point(sin(z * 0.46 + 0.8) * 1.25 + 0.65, z, 0.020))
		river.append(_art_point(x, 2.25 + sin(x * 0.38 + 1.2) * 0.55, 0.010))

	_append_ribbon_geometry(shoulders, main_road, ART_ROAD_SHOULDER_KM, 0.0)
	_append_ribbon_geometry(roads, main_road, ART_ROAD_WIDTH_KM, 0.004)
	_append_ribbon_geometry(shoulders, cross_road, ART_ROAD_SHOULDER_KM * 0.82, 0.0)
	_append_ribbon_geometry(roads, cross_road, ART_ROAD_WIDTH_KM * 0.72, 0.004)
	_append_ribbon_geometry(creek_bank, river, ART_CREEK_WIDTH_KM * 2.2, 0.002)
	_append_ribbon_geometry(creek, river, ART_CREEK_WIDTH_KM, 0.004)

	# Compact Syrian-inspired settlement block around the road junction.
	var building_count := 0
	for rz in range(-3, 4):
		for rx in range(-4, 5):
			if (rx + rz) % 3 == 0:
				continue
			var x := float(rx) * 0.26 + 0.85
			var z := float(rz) * 0.22 - 0.20
			if abs(x) < 0.20 or abs(z) < 0.18:
				continue
			var base := _art_point(x, z, 0.012)
			var sx := 0.11 + 0.025 * float(abs(rx) % 2)
			var sz := 0.09 + 0.020 * float(abs(rz) % 2)
			var h := 0.045 + 0.012 * float((abs(rx + rz) % 3))
			_append_art_box(buildings, base, sx, sz, h)
			building_count += 1

	_commit_vector_batch(shoulders, "ArtRoadShoulders", Color(0.37, 0.28, 0.17, 1.0))
	_commit_vector_batch(roads, "ArtDirtRoads", Color(0.70, 0.58, 0.38, 1.0))
	_commit_vector_batch(creek_bank, "ArtCreekBank", Color(0.42, 0.34, 0.20, 1.0))
	_commit_vector_batch(creek, "ArtCreek", Color(0.08, 0.34, 0.39, 1.0))
	_commit_vector_batch(buildings, "ArtSettlement", Color(0.72, 0.62, 0.50, 1.0))

	var grove: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 91001 + _governorate_index * 1009
	for i in range(170):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := rng.randf_range(-5.8, 5.8)
		var z := rng.randf_range(-4.7, 4.7)
		if abs(z - (sin(x * 0.55) * 0.90 - 0.35)) < 0.45:
			continue
		if abs(z - 2.25) < 0.38:
			continue
		if abs(x - 0.85) < 1.55 and abs(z + 0.20) < 1.20:
			continue
		z += side * 0.20
		var origin := _art_point(x, z, 0.008)
		var s := rng.randf_range(0.82, 1.22)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
			Vector3(0.010 * s, 0.019 * s, 0.010 * s)
		)
		grove.append(Transform3D(basis, origin))

	_commit_tree_multimesh(grove, "ArtTrees", Color(0.20, 0.38, 0.10, 1.0))

	_road_feature_count = 2
	_building_feature_count = building_count
	_water_feature_count = 1
	_landcover_feature_count = 1
	_tree_instance_count = grove.size()
	_feature_count = _road_feature_count + _building_feature_count + _water_feature_count + _landcover_feature_count
	_add_fallback_governorate_label()


func _refresh_vector_data(force: bool) -> void:
	if not _terrain_mode or _is_tactical_overview() or _vector_inflight:
		return
	if _vector_loaded and not force:
		return

	_vector_inflight = true
	_last_vector_center = Vector2(_center_lon, _center_lat)
	_build_art_directed_battlefield()
	_vector_loaded = true
	_vector_inflight = false
	_update_status()



func _setup_geo_overlay_layer() -> void:
	if is_instance_valid(_geo_overlay_root):
		return
	_geo_overlay_root = Node3D.new()
	_geo_overlay_root.name = "GeoOverlay"
	add_child(_geo_overlay_root)
	_load_geo_overlay_data()
	_update_geo_overlay_button()


func _load_geo_overlay_data() -> void:
	_geo_overlay_data = {}
	if not FileAccess.file_exists(STRATEGIC_OVERLAY_PATH):
		return
	var file := FileAccess.open(STRATEGIC_OVERLAY_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_geo_overlay_data = parsed


func _update_geo_overlay_button() -> void:
	if geo_overlay_button == null:
		return
	geo_overlay_button.text = "الحدود والأسماء: ظاهرة" if _geo_overlay_enabled else "الحدود والأسماء: مخفية"


func _on_geo_overlay_pressed() -> void:
	_geo_overlay_enabled = not _geo_overlay_enabled
	_update_geo_overlay_button()
	_refresh_geo_overlay(true)


func _clear_geo_overlay() -> void:
	if not is_instance_valid(_geo_overlay_root):
		return
	for child in _geo_overlay_root.get_children():
		child.free()
	_geo_overlay_boundary_count = 0
	_geo_overlay_label_count = 0


func _boundary_min_zoom(level: int) -> int:
	match level:
		2:
			return 6
		4:
			return 6
		6:
			return 7
		8:
			return 9
		_:
			return 11


func _boundary_width_km(level: int) -> float:
	var base := 0.045
	if _map_zoom <= 6:
		base = 0.72
	elif _map_zoom == 7:
		base = 0.38
	elif _map_zoom == 8:
		base = 0.20
	elif _map_zoom == 9:
		base = 0.075
	if level == 2:
		return base * 1.8
	if level == 4:
		return base * 1.25
	if level == 6:
		return base * 0.78
	return base * 0.52


func _boundary_color(level: int) -> Color:
	match level:
		2:
			return Color(1.0, 0.89, 0.46, 0.96)
		4:
			return Color(0.96, 0.94, 0.84, 0.90)
		6:
			return Color(0.93, 0.74, 0.40, 0.78)
		_:
			return Color(0.86, 0.82, 0.70, 0.58)


func _geo_overlay_bounds() -> Rect2:
	if _terrain_mode and _is_tactical_overview():
		var viewport := get_viewport().get_visible_rect().size
		var aspect := maxf(0.2, float(viewport.x) / maxf(1.0, float(viewport.y)))
		var half_lat := rad_to_deg((camera.size * 0.56) / EARTH_RADIUS_KM)
		var lon_radius := EARTH_RADIUS_KM * maxf(0.15, cos(deg_to_rad(_center_lat)))
		var half_lon := rad_to_deg((camera.size * aspect * 0.56) / lon_radius)
		return Rect2(_center_lon - half_lon, _center_lat - half_lat, half_lon * 2.0, half_lat * 2.0)

	var lat_radius := 0.075 if _map_zoom >= 10 else 0.20
	var lon_radius_deg := 0.095 if _map_zoom >= 10 else 0.25
	return Rect2(_center_lon - lon_radius_deg, _center_lat - lat_radius, lon_radius_deg * 2.0, lat_radius * 2.0)


func _geo_point_in_bounds(lon: float, lat: float, bounds: Rect2, margin: float = 0.0) -> bool:
	return (
		lon >= bounds.position.x - margin
		and lon <= bounds.end.x + margin
		and lat >= bounds.position.y - margin
		and lat <= bounds.end.y + margin
	)


func _geo_segment_intersects_bounds(a: Vector2, b: Vector2, bounds: Rect2) -> bool:
	if _geo_point_in_bounds(a.x, a.y, bounds, 0.03) or _geo_point_in_bounds(b.x, b.y, bounds, 0.03):
		return true
	var min_lon := minf(a.x, b.x)
	var max_lon := maxf(a.x, b.x)
	var min_lat := minf(a.y, b.y)
	var max_lat := maxf(a.y, b.y)
	return not (
		max_lon < bounds.position.x
		or min_lon > bounds.end.x
		or max_lat < bounds.position.y
		or min_lat > bounds.end.y
	)


func _overview_height_at_geo(lon: float, lat: float) -> float:
	if _strategic_height_image == null or _strategic_height_image.is_empty():
		var height_texture := load(STRATEGIC_HEIGHT_PATH) as Texture2D
		if height_texture != null:
			_strategic_height_image = height_texture.get_image()
	if _strategic_height_image == null or _strategic_height_image.is_empty():
		return 0.0
	var u := clampf((lon - REGION_WEST) / (REGION_EAST - REGION_WEST), 0.0, 1.0)
	var v := clampf((REGION_NORTH - lat) / (REGION_NORTH - REGION_SOUTH), 0.0, 1.0)
	return _strategic_height_at(_strategic_height_image, u, v) / 1000.0 * STRATEGIC_RELIEF_EXAGGERATION


func _overlay_height_at_geo(lon: float, lat: float) -> float:
	if _terrain_mode and _is_tactical_overview():
		return _overview_height_at_geo(lon, lat)
	return _height_at_geo(lon, lat)


func _append_geo_boundary_segment(st: SurfaceTool, a_geo: Vector2, b_geo: Vector2, width_km: float) -> void:
	var a := _geo_to_local(a_geo.x, a_geo.y, _overlay_height_at_geo(a_geo.x, a_geo.y) + 0.035)
	var b := _geo_to_local(b_geo.x, b_geo.y, _overlay_height_at_geo(b_geo.x, b_geo.y) + 0.035)
	var delta := Vector2(b.x - a.x, b.z - a.z)
	if delta.length() < 0.0001:
		return
	var direction := delta.normalized()
	var side := Vector3(-direction.y, 0.0, direction.x) * width_km * 0.5
	st.add_vertex(a - side)
	st.add_vertex(b - side)
	st.add_vertex(a + side)
	st.add_vertex(a + side)
	st.add_vertex(b - side)
	st.add_vertex(b + side)


func _commit_geo_boundary_batch(st: SurfaceTool, level: int, count: int) -> void:
	if count <= 0:
		return
	var mesh := st.commit()
	if mesh == null:
		return
	var node := MeshInstance3D.new()
	node.name = "AdminBoundary_%d" % level
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = _boundary_color(level)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	_geo_overlay_root.add_child(node)


func _geo_overlay_label_allowed(item: Dictionary) -> bool:
	if _map_zoom < int(item.get("min_zoom", 10)):
		return false
	if not (_terrain_mode and _is_tactical_overview()):
		return true

	var kind: String = str(item.get("kind", ""))
	if kind == "place":
		var place_type: String = str(item.get("type", ""))
		if _map_zoom <= 6:
			return place_type == "city"
		if _map_zoom == 7:
			return place_type in ["city", "town"]
		return place_type in ["city", "town"]

	if kind == "admin":
		var level: int = int(item.get("level", 99))
		if _map_zoom <= 7:
			return level <= 4
		return level <= 6

	return true


func _geo_overlay_label_priority(item: Dictionary) -> int:
	var kind: String = str(item.get("kind", ""))
	if kind == "place":
		match str(item.get("type", "")):
			"city":
				return 0
			"town":
				return 2
			"village":
				return 5
			_:
				return 8
	if kind == "admin":
		match int(item.get("level", 99)):
			2:
				return 1
			4:
				return 3
			6:
				return 6
			_:
				return 9
	return 10


func _sort_geo_overlay_labels(a, b) -> bool:
	var left: Dictionary = a
	var right: Dictionary = b
	return _geo_overlay_label_priority(left) < _geo_overlay_label_priority(right)


func _geo_overlay_label_font_size(item: Dictionary) -> int:
	if str(item.get("kind", "")) == "place":
		match str(item.get("type", "")):
			"city":
				return 26
			"town":
				return 22
			"village":
				return 18
			_:
				return 16

	match int(item.get("level", 99)):
		2:
			return 25
		4:
			return 21
		6:
			return 17
		_:
			return 15


func _geo_overlay_label_pixel_size(item: Dictionary) -> float:
	if _terrain_mode and _is_tactical_overview():
		var viewport_height: float = maxf(1.0, float(get_viewport().get_visible_rect().size.y))
		var world_per_pixel: float = float(camera.size) / viewport_height
		var scale_factor: float = 0.90
		if _geo_overlay_label_priority(item) <= 1:
			scale_factor = 1.0
		elif _geo_overlay_label_priority(item) >= 6:
			scale_factor = 0.82
		return world_per_pixel * scale_factor

	match str(item.get("type", "")):
		"city":
			return 0.0024
		"town":
			return 0.0021
		_:
			return 0.0018


func _geo_overlay_label_padding_px() -> float:
	match _map_zoom:
		6:
			return 34.0
		7:
			return 26.0
		8:
			return 20.0
		9:
			return 14.0
		_:
			return 10.0


func _geo_overlay_label_limit() -> int:
	match _map_zoom:
		6:
			return 14
		7:
			return 24
		8:
			return 36
		9:
			return 58
		_:
			return 72


func _add_geo_overlay_label(item: Dictionary, screen_boxes: Array) -> bool:
	var label_text: String = str(item.get("name", ""))
	if label_text.is_empty():
		return false

	var lon: float = float(item.get("lon", 0.0))
	var lat: float = float(item.get("lat", 0.0))
	var world: Vector3 = _geo_to_local(lon, lat, _overlay_height_at_geo(lon, lat) + 0.10)
	if camera.is_position_behind(world):
		return false

	var screen: Vector2 = camera.unproject_position(world)
	var font_size: int = _geo_overlay_label_font_size(item)
	var estimated_width: float = clampf(float(label_text.length()) * float(font_size) * 0.58, 54.0, 250.0)
	var estimated_height: float = maxf(28.0, float(font_size) * 1.45)
	var padding: float = _geo_overlay_label_padding_px()
	var box := Rect2(
		screen - Vector2(estimated_width, estimated_height) * 0.5 - Vector2.ONE * padding,
		Vector2(estimated_width, estimated_height) + Vector2.ONE * padding * 2.0
	)
	for occupied in screen_boxes:
		if box.intersects(occupied):
			return false
	screen_boxes.append(box)

	var label := Label3D.new()
	label.text = label_text
	label.position = world
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# World-space text is required on Android. fixed_size caused labels to
	# explode to hundreds of pixels and cover the battlefield at Z7-Z10.
	label.fixed_size = false
	label.font_size = font_size
	label.pixel_size = _geo_overlay_label_pixel_size(item)
	label.outline_size = 4 if _geo_overlay_label_priority(item) <= 3 else 3
	label.modulate = Color(1.0, 0.97, 0.84, 0.96)
	label.outline_modulate = Color(0.05, 0.06, 0.05, 0.92)
	_geo_overlay_root.add_child(label)
	return true


func _refresh_geo_overlay(force: bool = false) -> void:
	if not is_instance_valid(_geo_overlay_root):
		return

	_geo_overlay_root.visible = _geo_overlay_enabled and _terrain_mode
	if not _geo_overlay_root.visible:
		return
	if _geo_overlay_data.is_empty():
		_load_geo_overlay_data()
		if _geo_overlay_data.is_empty():
			return

	var current_origin := Vector2(_origin_lon, _origin_lat)
	if not force and _last_geo_overlay_zoom == _map_zoom and _last_geo_overlay_origin.distance_to(current_origin) < 0.00001:
		return

	_clear_geo_overlay()
	_last_geo_overlay_zoom = _map_zoom
	_last_geo_overlay_origin = current_origin
	var bounds := _geo_overlay_bounds()

	var levels := [2, 4, 6, 8]
	for level in levels:
		if _map_zoom < _boundary_min_zoom(level):
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segment_count := 0
		for feature in _geo_overlay_data.get("boundaries", []):
			if int(feature.get("level", 0)) != level:
				continue
			var points: Array = feature.get("points", [])
			for i in range(points.size() - 1):
				var raw_a = points[i]
				var raw_b = points[i + 1]
				if raw_a.size() < 2 or raw_b.size() < 2:
					continue
				var a := Vector2(float(raw_a[0]), float(raw_a[1]))
				var b := Vector2(float(raw_b[0]), float(raw_b[1]))
				if not _geo_segment_intersects_bounds(a, b, bounds):
					continue
				_append_geo_boundary_segment(st, a, b, _boundary_width_km(level))
				segment_count += 1
		_commit_geo_boundary_batch(st, level, segment_count)
		_geo_overlay_boundary_count += segment_count

	var label_candidates: Array = []
	for raw_item in _geo_overlay_data.get("labels", []):
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item
		if not _geo_overlay_label_allowed(item):
			continue
		var lon: float = float(item.get("lon", 0.0))
		var lat: float = float(item.get("lat", 0.0))
		if not _geo_point_in_bounds(lon, lat, bounds, 0.02):
			continue
		label_candidates.append(item)

	label_candidates.sort_custom(_sort_geo_overlay_labels)
	var screen_boxes: Array = []
	var label_limit: int = _geo_overlay_label_limit()
	for raw_item in label_candidates:
		var item: Dictionary = raw_item
		if _add_geo_overlay_label(item, screen_boxes):
			_geo_overlay_label_count += 1
			if _geo_overlay_label_count >= label_limit:
				break


func _setup_army_combat_core() -> void:
	var game_state := _game_state_node()
	if game_state == null or not bool(game_state.call("ensure_started")):
		push_error("DAM GameState: persistent army failed to initialize")
		_army_core = null
		return
	if not bool(game_state.call("ensure_heavy_force_roster", GOVERNORATES)):
		push_error("DAM GameState: heavy force roster failed to initialize")
		_army_core = null
		return
	_army_core = game_state.get("army_core")


func get_country_army_snapshot(country_id: String = "syria") -> Dictionary:
	if _army_core == null:
		return {}
	return _army_core.get_country_snapshot(country_id)


func purchase_country_units(unit_type: String, quantity: int = 1, country_id: String = "syria") -> Dictionary:
	if _army_core == null:
		return {"ok": false, "reason": "army_core_unavailable"}
	return _army_core.purchase(country_id, unit_type, quantity)


func resolve_logical_heavy_attack(attacker_id: String, target_id: String, weapon_id: String) -> Dictionary:
	var game_state := _game_state_node()
	if game_state == null:
		return {"ok": false, "reason": "game_state_missing"}
	var result: Dictionary = game_state.call("resolve_heavy_shot", attacker_id, target_id, weapon_id)
	if not bool(result.get("ok", false)):
		return result
	if not bool(game_state.call("apply_heavy_shot_result", target_id, result)):
		return {"ok": false, "reason": "persistent_combat_result_failed"}

	var logical_after: Dictionary = game_state.call("get_heavy_unit", target_id)
	if logical_after.is_empty():
		return {"ok": false, "reason": "target_state_missing_after_shot"}

	for i in range(_units.size()):
		var unit: Dictionary = _units[i]
		if str(unit.get("logical_unit_id", "")) != target_id:
			continue
		unit["hp"] = float(logical_after.get("hp", unit.get("hp", 0.0)))
		unit["alive"] = bool(logical_after.get("alive", unit.get("alive", true)))
		var combat_state: Dictionary = unit.get("combat_state", {})
		if not combat_state.is_empty():
			combat_state["hp"] = float(unit["hp"])
			combat_state["alive"] = bool(unit["alive"])
			unit["combat_state"] = combat_state
		_units[i] = unit
		break

	_sync_unit_visuals()
	_sync_detail_unit_lod()
	result["target_id"] = target_id
	result["target_hp"] = float(logical_after.get("hp", 0.0))
	result["target_alive"] = bool(logical_after.get("alive", false))
	return result


func resolve_unit_attack(attacker_index: int, target_index: int, weapon_id: String = "tank_cannon") -> Dictionary:
	if _army_core == null:
		return {"ok": false, "reason": "army_core_unavailable"}
	if attacker_index < 0 or attacker_index >= _units.size():
		return {"ok": false, "reason": "invalid_attacker"}
	if target_index < 0 or target_index >= _units.size():
		return {"ok": false, "reason": "invalid_target"}
	if attacker_index == target_index:
		return {"ok": false, "reason": "same_unit"}

	var attacker: Dictionary = _units[attacker_index]
	var target: Dictionary = _units[target_index]
	if not bool(attacker.get("alive", true)) or not bool(target.get("alive", true)):
		return {"ok": false, "reason": "unit_destroyed"}

	var result: Dictionary = _army_core.resolve_shot(
		attacker.get("combat_state", {}),
		target.get("combat_state", {}),
		weapon_id
	)
	if not bool(result.get("ok", false)):
		return result

	var updated_state: Dictionary = result.get("target", {})
	target["combat_state"] = updated_state
	target["hp"] = float(updated_state.get("hp", 0.0))
	target["alive"] = bool(updated_state.get("alive", false))
	var logical_id := str(target.get("logical_unit_id", ""))
	var game_state := _game_state_node()
	if bool(target["alive"]) and not logical_id.is_empty() and game_state != null:
		if not bool(game_state.call("update_heavy_surviving_hp", logical_id, float(target["hp"]))):
			return {"ok": false, "reason": "persistent_hp_failed"}
	if not bool(target["alive"]):
		target["moving"] = false
		if not logical_id.is_empty() and game_state != null:
			if not bool(game_state.call("record_heavy_loss", logical_id)):
				return {"ok": false, "reason": "persistent_loss_failed"}
	_units[target_index] = target
	if not bool(target.get("alive", true)):
		var wreck_node = target.get("node")
		if wreck_node is Node3D and is_instance_valid(wreck_node):
			_apply_wreck_visual(wreck_node)
	_sync_unit_visuals()
	return result


func _append_governorate_unit(governorate_index: int, unit_type: String) -> bool:
	if governorate_index < 0 or governorate_index >= GOVERNORATES.size():
		return false
	var gov: Dictionary = GOVERNORATES[governorate_index]
	var node := _create_heavy_unit_visual(unit_type, governorate_index)
	_unit_root.add_child(node)

	var combat_state: Dictionary = {}
	if _army_core != null:
		combat_state = _army_core.create_unit_state(unit_type, "syria")

	var unit_spec: Dictionary = _army_core.unit_spec(unit_type) if _army_core != null else {}
	var game_state := _game_state_node()
	var logical_unit_id := ""
	if game_state != null:
		logical_unit_id = str(game_state.call("get_heavy_representative_id", governorate_index, unit_type))
	var offset := _unit_type_spawn_offset(unit_type)
	var logical_state: Dictionary = {}
	if game_state != null and not logical_unit_id.is_empty():
		logical_state = game_state.call("get_heavy_unit", logical_unit_id)
	var spawn_lon := float(logical_state.get("lon", float(gov["lon"]) + offset.x))
	var spawn_lat := float(logical_state.get("lat", float(gov["lat"]) + offset.y))
	if not logical_state.is_empty() and not combat_state.is_empty():
		combat_state["hp"] = float(logical_state.get("hp", combat_state.get("hp", unit_spec.get("hp", 100.0))))
		combat_state["max_hp"] = float(logical_state.get("max_hp", combat_state.get("max_hp", unit_spec.get("hp", 100.0))))
		combat_state["alive"] = bool(logical_state.get("alive", combat_state.get("alive", true)))
	_units.append({
		"army_id": governorate_index + 1,
		"country_id": "syria",
		"unit_type": unit_type,
		"logical_unit_id": logical_unit_id,
		"governorate_index": governorate_index,
		"lon": spawn_lon,
		"lat": spawn_lat,
		"target_lon": spawn_lon,
		"target_lat": spawn_lat,
		"moving": false,
		"alive": bool(combat_state.get("alive", true)),
		"hp": float(combat_state.get("hp", unit_spec.get("hp", 100.0))),
		"combat_state": combat_state,
		"speed_km_sec": float(combat_state.get("speed_km_sec", unit_spec.get("speed_km_sec", UNIT_SPEED_KM_PER_SEC))),
		"node": node,
	})
	return true


func _setup_unit_layer() -> void:
	if is_instance_valid(_unit_root):
		return

	_unit_root = Node3D.new()
	_unit_root.name = "PersistentUnits"
	add_child(_unit_root)

	_detail_unit_root = Node3D.new()
	_detail_unit_root.name = "DetailedUnits"
	add_child(_detail_unit_root)

	for i in range(GOVERNORATES.size()):
		for unit_type in ["tank", "artillery", "rocket_launcher"]:
			_append_governorate_unit(i, unit_type)


func _create_detail_unit_visual(logical: Dictionary) -> Node3D:
	var governorate_index := int(logical.get("current_governorate_index", -1))
	var unit_type := str(logical.get("unit_type", ""))
	var logical_id := str(logical.get("id", ""))
	if governorate_index < 0 or governorate_index >= GOVERNORATES.size() or logical_id.is_empty():
		return null
	var node := _create_heavy_unit_visual(unit_type, governorate_index)
	node.name = "Detail_" + logical_id
	node.set_meta("logical_unit_id", logical_id)
	node.set_meta("detail_unit", true)
	var marker := node.get_node_or_null("MapMarker") as Node3D
	var selection := node.get_node_or_null("Selection") as Node3D
	if marker != null:
		marker.visible = false
	if selection != null:
		selection.visible = false
	var lon := float(logical.get("lon", 0.0))
	var lat := float(logical.get("lat", 0.0))
	var height := _designed_height_m(lon, lat) / 1000.0 + 0.012
	node.position = _geo_to_local(lon, lat, height)
	node.rotation.y = float(logical.get("heading_rad", 0.0))
	node.scale = Vector3.ONE * get_rts_unit_visual_scale()
	var model := _get_unit_model_node(node)
	if model != null:
		model.visible = _terrain_mode
	if not bool(logical.get("alive", true)):
		_apply_wreck_visual(node)
		node.set_meta("logical_wreck", true)
	return node


func _clear_detail_unit_visuals() -> void:
	if not is_instance_valid(_detail_unit_root):
		return
	for child in _detail_unit_root.get_children():
		_detail_unit_root.remove_child(child)
		child.queue_free()
	_detail_unit_nodes.clear()
	_detail_governorate_index = -1


func _rebuild_detail_unit_visuals() -> void:
	_clear_detail_unit_visuals()
	if _rts_zoom_level < RTS_DETAIL_UNIT_LOD_MIN or not is_instance_valid(_detail_unit_root):
		return
	var game_state := _game_state_node()
	if game_state == null:
		return
	var roster_units: Array = game_state.call("get_heavy_units_for_governorate", _governorate_index, false)
	var representative_ids := {}
	for representative in _units:
		if int(representative.get("governorate_index", -1)) != _governorate_index:
			continue
		var representative_id := str(representative.get("logical_unit_id", ""))
		if not representative_id.is_empty():
			representative_ids[representative_id] = true
	for raw_logical in roster_units:
		var logical: Dictionary = raw_logical
		var logical_id := str(logical.get("id", ""))
		if representative_ids.has(logical_id):
			continue
		var node := _create_detail_unit_visual(logical)
		if node == null:
			continue
		_detail_unit_root.add_child(node)
		_detail_unit_nodes.append(node)
	_detail_governorate_index = _governorate_index


func _sync_detail_unit_lod(force: bool = false) -> void:
	if _rts_zoom_level < RTS_DETAIL_UNIT_LOD_MIN:
		if not _detail_unit_nodes.is_empty():
			_clear_detail_unit_visuals()
		return
	if force or _detail_governorate_index != _governorate_index or _detail_unit_nodes.is_empty():
		_rebuild_detail_unit_visuals()
		return
	var scale_value := get_rts_unit_visual_scale()
	var game_state := _game_state_node()
	for node in _detail_unit_nodes:
		if not is_instance_valid(node):
			continue
		node.scale = Vector3.ONE * scale_value
		if game_state == null:
			continue
		var logical_id: String = str(node.get_meta("logical_unit_id", ""))
		if logical_id.is_empty():
			continue
		var logical: Dictionary = game_state.call("get_heavy_unit", logical_id)
		if logical.is_empty():
			node.visible = false
			continue
		if not bool(logical.get("alive", true)):
			node.visible = true
			_apply_wreck_visual(node)
			node.set_meta("logical_wreck", true)
			var wreck_selection := node.get_node_or_null("Selection")
			if wreck_selection != null:
				wreck_selection.visible = false
			continue
		node.visible = true
		node.set_meta("logical_wreck", false)
		var lon: float = float(logical.get("lon", 0.0))
		var lat: float = float(logical.get("lat", 0.0))
		var height: float = _designed_height_m(lon, lat) / 1000.0 + 0.012
		node.position = _geo_to_local(lon, lat, height)
		node.rotation.y = float(logical.get("heading_rad", node.rotation.y))
		var selection := node.get_node_or_null("Selection")
		if selection != null:
			var is_selected: bool = logical_id in _selected_logical_unit_ids
			selection.visible = is_selected
			var is_primary: bool = is_selected and not _selected_logical_unit_ids.is_empty() and logical_id == _selected_logical_unit_ids.back()
			var ring_scale: float = 1.28 if is_primary else (0.92 if is_selected and _selected_logical_unit_ids.size() > 1 else 1.0)
			selection.scale = Vector3.ONE * ring_scale


func get_detail_unit_visual_count() -> int:
	var count := 0
	for node in _detail_unit_nodes:
		if is_instance_valid(node):
			count += 1
	return count


func _army_color(index: int) -> Color:
	var hue := fmod(float(index) * 0.61803398875, 1.0)
	return Color.from_hsv(hue, 0.78, 0.96, 1.0)


func _solid_unshaded_material(color: Color, emission_strength: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	material.metallic = 0.08
	if emission_strength > 0.0:
		material.emission_enabled = true
		material.emission = color * emission_strength
	return material


func _tank_family(index: int) -> String:
	return "western" if index % 2 == 0 else "eastern"


func _unit_type_spawn_offset(unit_type: String) -> Vector2:
	match unit_type:
		"artillery":
			return Vector2(0.018, 0.010)
		"rocket_launcher":
			return Vector2(-0.018, 0.010)
		_:
			return Vector2.ZERO


func _create_artillery_visual(index: int) -> Node3D:
	var root_node := Node3D.new()
	root_node.name = "ArmyArtillery_%02d" % [index + 1]
	var army_color := _army_color(index)
	var family := _tank_family(index)
	root_node.set_meta("visual_family", family)
	root_node.set_meta("unit_type", "artillery")

	var model := Node3D.new()
	model.name = "ArtilleryModel"
	root_node.add_child(model)

	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(1.66, 0.38, 2.34) if family == "western" else Vector3(1.48, 0.34, 2.18)
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = hull_mesh
	hull.position.y = 0.28
	hull.material_override = _solid_unshaded_material(army_color.darkened(0.22))
	model.add_child(hull)

	for side in [-1.0, 1.0]:
		var track_mesh := BoxMesh.new()
		track_mesh.size = Vector3(0.25, 0.28, 2.28 if family == "western" else 2.10)
		var track := MeshInstance3D.new()
		track.name = "TrackLeft" if side < 0.0 else "TrackRight"
		track.mesh = track_mesh
		track.position = Vector3(side * (0.85 if family == "western" else 0.76), 0.18, 0.02)
		track.material_override = _solid_unshaded_material(Color(0.10, 0.11, 0.10, 1.0))
		model.add_child(track)

	var wheel_positions := [-0.78, -0.39, 0.0, 0.39, 0.78]
	for side in [-1.0, 1.0]:
		for wheel_index in range(wheel_positions.size()):
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.18
			wheel_mesh.bottom_radius = 0.18
			wheel_mesh.height = 0.15
			wheel_mesh.radial_segments = 10
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel_%s_%02d" % ["L" if side < 0.0 else "R", wheel_index]
			wheel.mesh = wheel_mesh
			wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			wheel.position = Vector3(side * (0.88 if family == "western" else 0.79), 0.19, float(wheel_positions[wheel_index]))
			wheel.material_override = _solid_unshaded_material(Color(0.16, 0.17, 0.15, 1.0))
			model.add_child(wheel)

	var turret_pivot := Node3D.new()
	turret_pivot.name = "TurretPivot"
	model.add_child(turret_pivot)

	var turret_mesh := BoxMesh.new()
	turret_mesh.size = Vector3(1.18, 0.42, 1.12) if family == "western" else Vector3(1.02, 0.36, 1.04)
	var turret := MeshInstance3D.new()
	turret.name = "Turret"
	turret.mesh = turret_mesh
	turret.position = Vector3(0.0, 0.65 if family == "western" else 0.58, 0.06)
	turret.material_override = _solid_unshaded_material(army_color)
	turret_pivot.add_child(turret)

	var gun_mount := Node3D.new()
	gun_mount.name = "GunMount"
	gun_mount.position = Vector3(0.0, 0.69 if family == "western" else 0.61, -0.48)
	turret_pivot.add_child(gun_mount)

	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.13, 0.13, 2.44 if family == "western" else 2.22)
	var barrel := MeshInstance3D.new()
	barrel.name = "Barrel"
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0.0, 0.0, -1.30 if family == "western" else -1.18)
	barrel.material_override = _solid_unshaded_material(army_color.lightened(0.06))
	gun_mount.add_child(barrel)

	for side in [-1.0, 1.0]:
		var stabilizer_mesh := BoxMesh.new()
		stabilizer_mesh.size = Vector3(0.18, 0.14, 0.68)
		var stabilizer := MeshInstance3D.new()
		stabilizer.name = "RearStabilizerLeft" if side < 0.0 else "RearStabilizerRight"
		stabilizer.mesh = stabilizer_mesh
		stabilizer.position = Vector3(side * 0.58, 0.14, 1.12)
		stabilizer.rotation_degrees.x = -12.0
		stabilizer.material_override = _solid_unshaded_material(army_color.darkened(0.18))
		model.add_child(stabilizer)

	var marker := Node3D.new()
	marker.name = "MapMarker"
	root_node.add_child(marker)
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 1.0
	marker_mesh.bottom_radius = 1.0
	marker_mesh.height = 0.12
	marker_mesh.radial_segments = 18
	var marker_disc := MeshInstance3D.new()
	marker_disc.mesh = marker_mesh
	marker_disc.material_override = _solid_unshaded_material(army_color, 0.25)
	marker.add_child(marker_disc)

	var marker_label := Label3D.new()
	marker_label.text = "A"
	marker_label.position = Vector3(0.0, 0.18, 0.0)
	marker_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	marker_label.font_size = 30
	marker_label.pixel_size = 0.015
	marker_label.modulate = Color.WHITE
	marker.add_child(marker_label)

	var selection_mesh := CylinderMesh.new()
	selection_mesh.top_radius = 1.45
	selection_mesh.bottom_radius = 1.45
	selection_mesh.height = 0.055
	selection_mesh.radial_segments = 24
	var selection := MeshInstance3D.new()
	selection.name = "Selection"
	selection.mesh = selection_mesh
	selection.position.y = 0.03
	selection.material_override = _solid_unshaded_material(Color(1.0, 0.92, 0.20, 0.82), 0.50)
	selection.visible = false
	root_node.add_child(selection)

	var engine_audio := AudioStreamPlayer3D.new()
	engine_audio.name = "EngineAudio"
	engine_audio.max_distance = 42.0
	engine_audio.unit_size = 3.0
	root_node.add_child(engine_audio)

	var weapon_audio := AudioStreamPlayer3D.new()
	weapon_audio.name = "WeaponAudio"
	weapon_audio.max_distance = 72.0
	weapon_audio.unit_size = 4.0
	root_node.add_child(weapon_audio)

	return root_node


func _create_launcher_visual(index: int) -> Node3D:
	var root_node := Node3D.new()
	root_node.name = "ArmyLauncher_%02d" % [index + 1]
	var army_color := _army_color(index)
	var family := _tank_family(index)
	root_node.set_meta("visual_family", family)
	root_node.set_meta("unit_type", "rocket_launcher")

	var model := Node3D.new()
	model.name = "LauncherModel"
	root_node.add_child(model)

	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(1.64, 0.38, 2.42) if family == "western" else Vector3(1.50, 0.34, 2.24)
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = hull_mesh
	hull.position.y = 0.28
	hull.material_override = _solid_unshaded_material(army_color.darkened(0.22))
	model.add_child(hull)

	for side in [-1.0, 1.0]:
		var track_mesh := BoxMesh.new()
		track_mesh.size = Vector3(0.25, 0.28, 2.34 if family == "western" else 2.14)
		var track := MeshInstance3D.new()
		track.name = "TrackLeft" if side < 0.0 else "TrackRight"
		track.mesh = track_mesh
		track.position = Vector3(side * (0.84 if family == "western" else 0.76), 0.18, 0.02)
		track.material_override = _solid_unshaded_material(Color(0.10, 0.11, 0.10, 1.0))
		model.add_child(track)

	var wheel_positions := [-0.80, -0.40, 0.0, 0.40, 0.80]
	for side in [-1.0, 1.0]:
		for wheel_index in range(wheel_positions.size()):
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.18
			wheel_mesh.bottom_radius = 0.18
			wheel_mesh.height = 0.15
			wheel_mesh.radial_segments = 10
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel_%s_%02d" % ["L" if side < 0.0 else "R", wheel_index]
			wheel.mesh = wheel_mesh
			wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			wheel.position = Vector3(side * (0.87 if family == "western" else 0.79), 0.19, float(wheel_positions[wheel_index]))
			wheel.material_override = _solid_unshaded_material(Color(0.16, 0.17, 0.15, 1.0))
			model.add_child(wheel)

	var launcher_pivot := Node3D.new()
	launcher_pivot.name = "LauncherPivot"
	launcher_pivot.position = Vector3(0.0, 0.62 if family == "western" else 0.56, 0.04)
	model.add_child(launcher_pivot)

	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.48
	base_mesh.bottom_radius = 0.54
	base_mesh.height = 0.18
	base_mesh.radial_segments = 12
	var rotating_base := MeshInstance3D.new()
	rotating_base.name = "RotatingBase"
	rotating_base.mesh = base_mesh
	rotating_base.material_override = _solid_unshaded_material(army_color.darkened(0.05))
	launcher_pivot.add_child(rotating_base)

	var elevation_pivot := Node3D.new()
	elevation_pivot.name = "ElevationPivot"
	elevation_pivot.position = Vector3(0.0, 0.26, -0.12)
	launcher_pivot.add_child(elevation_pivot)

	var pod_mesh := BoxMesh.new()
	pod_mesh.size = Vector3(1.22, 0.64, 1.42) if family == "western" else Vector3(1.08, 0.58, 1.28)
	var pod := MeshInstance3D.new()
	pod.name = "RocketPod"
	pod.mesh = pod_mesh
	pod.position = Vector3(0.0, 0.18, -0.32)
	pod.material_override = _solid_unshaded_material(army_color)
	elevation_pivot.add_child(pod)

	for row in range(3):
		for column in range(4):
			var tube_mesh := CylinderMesh.new()
			tube_mesh.top_radius = 0.075
			tube_mesh.bottom_radius = 0.082
			tube_mesh.height = 0.72
			tube_mesh.radial_segments = 10
			var tube := MeshInstance3D.new()
			tube.name = "Tube_%02d" % (row * 4 + column)
			tube.mesh = tube_mesh
			tube.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			tube.position = Vector3(
				(float(column) - 1.5) * 0.24,
				0.18 + (float(row) - 1.0) * 0.18,
				-1.00
			)
			tube.material_override = _solid_unshaded_material(Color(0.11, 0.12, 0.10, 1.0))
			elevation_pivot.add_child(tube)

	var marker := Node3D.new()
	marker.name = "MapMarker"
	root_node.add_child(marker)
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 1.0
	marker_mesh.bottom_radius = 1.0
	marker_mesh.height = 0.12
	marker_mesh.radial_segments = 18
	var marker_disc := MeshInstance3D.new()
	marker_disc.mesh = marker_mesh
	marker_disc.material_override = _solid_unshaded_material(army_color, 0.25)
	marker.add_child(marker_disc)

	var marker_label := Label3D.new()
	marker_label.text = "R"
	marker_label.position = Vector3(0.0, 0.18, 0.0)
	marker_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	marker_label.font_size = 30
	marker_label.pixel_size = 0.015
	marker_label.modulate = Color.WHITE
	marker.add_child(marker_label)

	var selection_mesh := CylinderMesh.new()
	selection_mesh.top_radius = 1.45
	selection_mesh.bottom_radius = 1.45
	selection_mesh.height = 0.055
	selection_mesh.radial_segments = 24
	var selection := MeshInstance3D.new()
	selection.name = "Selection"
	selection.mesh = selection_mesh
	selection.position.y = 0.03
	selection.material_override = _solid_unshaded_material(Color(1.0, 0.92, 0.20, 0.82), 0.50)
	selection.visible = false
	root_node.add_child(selection)

	var engine_audio := AudioStreamPlayer3D.new()
	engine_audio.name = "EngineAudio"
	engine_audio.max_distance = 42.0
	engine_audio.unit_size = 3.0
	root_node.add_child(engine_audio)

	var weapon_audio := AudioStreamPlayer3D.new()
	weapon_audio.name = "WeaponAudio"
	weapon_audio.max_distance = 78.0
	weapon_audio.unit_size = 4.0
	root_node.add_child(weapon_audio)

	return root_node


func _create_heavy_unit_visual(unit_type: String, index: int) -> Node3D:
	match unit_type:
		"artillery":
			return _create_artillery_visual(index)
		"rocket_launcher":
			return _create_launcher_visual(index)
		_:
			return _create_tank_visual(index)


func _create_tank_visual(index: int) -> Node3D:
	var root_node := Node3D.new()
	root_node.name = "ArmyTank_%02d" % [index + 1]
	var army_color := _army_color(index)
	var family := _tank_family(index)
	root_node.set_meta("visual_family", family)

	var model := Node3D.new()
	model.name = "TankModel"
	root_node.add_child(model)

	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(1.78, 0.46, 2.56) if family == "western" else Vector3(1.52, 0.38, 2.30)
	var hull := MeshInstance3D.new()
	hull.mesh = hull_mesh
	hull.position.y = 0.32 if family == "western" else 0.28
	hull.material_override = _solid_unshaded_material(army_color.darkened(0.24))
	model.add_child(hull)

	var upper_hull_mesh := BoxMesh.new()
	upper_hull_mesh.size = Vector3(1.48, 0.22, 1.78) if family == "western" else Vector3(1.30, 0.18, 1.62)
	var upper_hull := MeshInstance3D.new()
	upper_hull.name = "UpperHull"
	upper_hull.mesh = upper_hull_mesh
	upper_hull.position = Vector3(0.0, 0.55 if family == "western" else 0.47, 0.08)
	upper_hull.material_override = _solid_unshaded_material(army_color.darkened(0.14))
	model.add_child(upper_hull)

	for side in [-1.0, 1.0]:
		var track_mesh := BoxMesh.new()
		track_mesh.size = Vector3(0.28, 0.30, 2.48 if family == "western" else 2.22)
		var track := MeshInstance3D.new()
		track.name = "TrackLeft" if side < 0.0 else "TrackRight"
		track.mesh = track_mesh
		track.position = Vector3(side * (0.91 if family == "western" else 0.79), 0.20, 0.0)
		track.material_override = _solid_unshaded_material(Color(0.10, 0.11, 0.10, 1.0))
		model.add_child(track)

	var wheel_positions := [-0.92, -0.56, -0.20, 0.20, 0.56, 0.92]
	for side in [-1.0, 1.0]:
		for wheel_index in range(wheel_positions.size()):
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.19 if family == "western" else 0.17
			wheel_mesh.bottom_radius = wheel_mesh.top_radius
			wheel_mesh.height = 0.16
			wheel_mesh.radial_segments = 12
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel_%s_%02d" % ["L" if side < 0.0 else "R", wheel_index]
			wheel.mesh = wheel_mesh
			wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			wheel.position = Vector3(side * (0.94 if family == "western" else 0.82), 0.20, float(wheel_positions[wheel_index]) * (1.03 if family == "western" else 0.92))
			wheel.material_override = _solid_unshaded_material(Color(0.16, 0.17, 0.15, 1.0))
			model.add_child(wheel)

	var turret_pivot := Node3D.new()
	turret_pivot.name = "TurretPivot"
	model.add_child(turret_pivot)

	var turret := MeshInstance3D.new()
	turret.name = "Turret"
	if family == "western":
		var western_turret_mesh := BoxMesh.new()
		western_turret_mesh.size = Vector3(1.32, 0.46, 1.36)
		turret.mesh = western_turret_mesh
		turret.position = Vector3(0.0, 0.73, -0.06)
	else:
		var eastern_turret_mesh := CylinderMesh.new()
		eastern_turret_mesh.top_radius = 0.50
		eastern_turret_mesh.bottom_radius = 0.62
		eastern_turret_mesh.height = 0.32
		eastern_turret_mesh.radial_segments = 16
		turret.mesh = eastern_turret_mesh
		turret.position = Vector3(0.0, 0.62, -0.04)
	turret.material_override = _solid_unshaded_material(army_color)
	turret_pivot.add_child(turret)

	var gun_mount := Node3D.new()
	gun_mount.name = "GunMount"
	gun_mount.position = Vector3(0.0, 0.74 if family == "western" else 0.64, -0.54 if family == "western" else -0.48)
	turret_pivot.add_child(gun_mount)

	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.15, 0.15, 1.86) if family == "western" else Vector3(0.13, 0.13, 1.62)
	var barrel := MeshInstance3D.new()
	barrel.name = "Barrel"
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0.0, 0.0, -1.00 if family == "western" else -0.88)
	barrel.material_override = _solid_unshaded_material(army_color.lightened(0.08))
	gun_mount.add_child(barrel)

	var hatch_mesh := CylinderMesh.new()
	hatch_mesh.top_radius = 0.20
	hatch_mesh.bottom_radius = 0.22
	hatch_mesh.height = 0.08
	hatch_mesh.radial_segments = 12
	var hatch := MeshInstance3D.new()
	hatch.name = "CommanderHatch"
	hatch.mesh = hatch_mesh
	hatch.position = Vector3(0.28 if family == "western" else 0.16, 0.98 if family == "western" else 0.82, 0.02)
	hatch.material_override = _solid_unshaded_material(army_color.lightened(0.04))
	turret_pivot.add_child(hatch)

	for side in [-1.0, 1.0]:
		var stowage_mesh := BoxMesh.new()
		stowage_mesh.size = Vector3(0.28, 0.22, 0.46)
		var stowage := MeshInstance3D.new()
		stowage.name = "TurretStowageLeft" if side < 0.0 else "TurretStowageRight"
		stowage.mesh = stowage_mesh
		stowage.position = Vector3(side * (0.58 if family == "western" else 0.50), 0.72 if family == "western" else 0.62, 0.42)
		stowage.material_override = _solid_unshaded_material(army_color.darkened(0.20))
		turret_pivot.add_child(stowage)

	for side in [-1.0, 1.0]:
		var skirt_mesh := BoxMesh.new()
		skirt_mesh.size = Vector3(0.12, 0.34, 2.18 if family == "western" else 1.96)
		var skirt := MeshInstance3D.new()
		skirt.name = "SideSkirtLeft" if side < 0.0 else "SideSkirtRight"
		skirt.mesh = skirt_mesh
		skirt.position = Vector3(side * (0.78 if family == "western" else 0.69), 0.35, 0.02)
		skirt.material_override = _solid_unshaded_material(army_color.darkened(0.10))
		model.add_child(skirt)

	var engine_deck_mesh := BoxMesh.new()
	engine_deck_mesh.size = Vector3(1.18, 0.12, 0.64)
	var engine_deck := MeshInstance3D.new()
	engine_deck.name = "EngineDeck"
	engine_deck.mesh = engine_deck_mesh
	engine_deck.position = Vector3(0.0, 0.60 if family == "western" else 0.51, 0.78)
	engine_deck.material_override = _solid_unshaded_material(army_color.darkened(0.28))
	model.add_child(engine_deck)

	var antenna_mesh := CylinderMesh.new()
	antenna_mesh.top_radius = 0.018
	antenna_mesh.bottom_radius = 0.024
	antenna_mesh.height = 0.78 if family == "western" else 0.58
	antenna_mesh.radial_segments = 8
	var antenna := MeshInstance3D.new()
	antenna.name = "TurretAntenna"
	antenna.mesh = antenna_mesh
	antenna.position = Vector3(-0.38 if family == "western" else -0.28, 1.16 if family == "western" else 0.98, 0.30)
	antenna.material_override = _solid_unshaded_material(Color(0.12, 0.13, 0.11, 1.0))
	turret_pivot.add_child(antenna)

	var marker := Node3D.new()
	marker.name = "MapMarker"
	root_node.add_child(marker)

	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 1.0
	marker_mesh.bottom_radius = 1.0
	marker_mesh.height = 0.12
	marker_mesh.radial_segments = 18
	var marker_disc := MeshInstance3D.new()
	marker_disc.mesh = marker_mesh
	marker_disc.material_override = _solid_unshaded_material(army_color, 0.25)
	marker.add_child(marker_disc)

	var marker_label := Label3D.new()
	marker_label.text = str(index + 1)
	marker_label.position = Vector3(0.0, 0.18, 0.0)
	marker_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	marker_label.font_size = 30
	marker_label.pixel_size = 0.015
	marker_label.modulate = Color.WHITE
	marker.add_child(marker_label)

	var selection_mesh := CylinderMesh.new()
	selection_mesh.top_radius = 1.45
	selection_mesh.bottom_radius = 1.45
	selection_mesh.height = 0.055
	selection_mesh.radial_segments = 24
	var selection := MeshInstance3D.new()
	selection.name = "Selection"
	selection.mesh = selection_mesh
	selection.position.y = 0.03
	selection.material_override = _solid_unshaded_material(Color(1.0, 0.92, 0.20, 0.82), 0.50)
	selection.visible = false
	root_node.add_child(selection)

	# Dedicated 3D audio channels are present from the start so movement,
	# weapons and impacts can receive real assets without changing unit logic.
	var engine_audio := AudioStreamPlayer3D.new()
	engine_audio.name = "EngineAudio"
	engine_audio.max_distance = 42.0
	engine_audio.unit_size = 3.0
	root_node.add_child(engine_audio)

	var weapon_audio := AudioStreamPlayer3D.new()
	weapon_audio.name = "WeaponAudio"
	weapon_audio.max_distance = 65.0
	weapon_audio.unit_size = 4.0
	root_node.add_child(weapon_audio)

	return root_node


func uses_unit_marker_lod(level: int = _rts_zoom_level) -> bool:
	return clampi(level, RTS_ZOOM_LEVEL_MIN, RTS_ZOOM_LEVEL_MAX) <= 3


func get_rts_unit_visual_scale(level: int = _rts_zoom_level) -> float:
	var clamped_level := clampi(level, RTS_ZOOM_LEVEL_MIN, RTS_ZOOM_LEVEL_MAX)
	if clamped_level <= 3:
		return float(RTS_MARKER_SCALES[clamped_level - 1])
	var t := float(clamped_level - 4) / float(RTS_ZOOM_LEVEL_MAX - 4)
	return lerpf(0.0085, 0.0038, t)


func validate_strategic_tank_visuals() -> String:
	var families := {}
	for unit in _units:
		if str(unit.get("unit_type", "")) != "tank":
			continue
		var node = unit.get("node")
		if not (node is Node3D) or not is_instance_valid(node):
			return "strategic tank node is missing"
		var family := str(node.get_meta("visual_family", ""))
		if family != "western" and family != "eastern":
			return "strategic tank visual family is invalid"
		families[family] = true
		for required_path in [
			"TankModel/UpperHull",
			"TankModel/TrackLeft",
			"TankModel/TrackRight",
			"TankModel/TurretPivot/Turret",
			"TankModel/TurretPivot/GunMount/Barrel",
			"TankModel/TurretPivot/CommanderHatch",
			"TankModel/EngineDeck",
		]:
			if node.get_node_or_null(required_path) == null:
				return "strategic tank visual missing %s" % required_path
	if not families.has("western") or not families.has("eastern"):
		return "both strategic tank families must be present"
	return ""


func validate_support_heavy_visuals() -> String:
	var artillery_count := 0
	var launcher_count := 0
	for unit in _units:
		var unit_type := str(unit.get("unit_type", ""))
		if unit_type != "artillery" and unit_type != "rocket_launcher":
			continue
		var node = unit.get("node")
		if not (node is Node3D) or not is_instance_valid(node):
			return "support heavy unit node is missing"
		if unit_type == "artillery":
			artillery_count += 1
			for required_path in [
				"ArtilleryModel/TrackLeft",
				"ArtilleryModel/TrackRight",
				"ArtilleryModel/TurretPivot/Turret",
				"ArtilleryModel/TurretPivot/GunMount/Barrel",
				"ArtilleryModel/RearStabilizerLeft",
				"ArtilleryModel/RearStabilizerRight",
			]:
				if node.get_node_or_null(required_path) == null:
					return "artillery visual missing %s" % required_path
		else:
			launcher_count += 1
			for required_path in [
				"LauncherModel/TrackLeft",
				"LauncherModel/TrackRight",
				"LauncherModel/LauncherPivot/RotatingBase",
				"LauncherModel/LauncherPivot/ElevationPivot/RocketPod",
				"LauncherModel/LauncherPivot/ElevationPivot/Tube_00",
				"LauncherModel/LauncherPivot/ElevationPivot/Tube_11",
			]:
				if node.get_node_or_null(required_path) == null:
					return "rocket launcher visual missing %s" % required_path
	if artillery_count != GOVERNORATES.size():
		return "artillery representative count does not match governorates"
	if launcher_count != GOVERNORATES.size():
		return "rocket launcher representative count does not match governorates"
	return ""


func _tank_visual_scale() -> float:
	if _terrain_mode:
		return get_rts_unit_visual_scale()
	return maxf(0.55, camera.size * 0.0085)


func _get_unit_model_node(node: Node3D) -> Node3D:
	for path in ["TankModel", "ArtilleryModel", "LauncherModel"]:
		var model := node.get_node_or_null(path) as Node3D
		if model != null:
			return model
	return null


func _orient_unit_hull_to_target(node: Node3D, unit: Dictionary) -> void:
	if not bool(unit.get("moving", false)):
		return
	var current := _geo_to_local(float(unit["lon"]), float(unit["lat"]), 0.0)
	var target := _geo_to_local(float(unit["target_lon"]), float(unit["target_lat"]), 0.0)
	var delta := Vector2(target.x - current.x, target.z - current.z)
	if delta.length_squared() <= 0.000001:
		return
	node.rotation.y = atan2(-delta.x, -delta.y)


func _apply_wreck_visual(node: Node3D) -> void:
	if not is_instance_valid(node) or bool(node.get_meta("is_wreck", false)):
		return
	node.set_meta("is_wreck", true)
	var model := _get_unit_model_node(node)
	if model == null:
		return
	model.rotation_degrees.z = -7.0
	model.position.y -= 0.05
	var wreck_overlay := StandardMaterial3D.new()
	wreck_overlay.albedo_color = Color(0.16, 0.14, 0.11, 1.0)
	wreck_overlay.roughness = 1.0
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_overlay = wreck_overlay
			if child is Node:
				stack.append(child)


func _sync_unit_visuals() -> void:
	if not is_instance_valid(_unit_root):
		return

	var scale_value := _tank_visual_scale()
	for i in range(_units.size()):
		var unit: Dictionary = _units[i]
		var node: Node3D = unit["node"]
		if not is_instance_valid(node):
			continue
		var alive := bool(unit.get("alive", true))
		node.visible = true

		var lon := float(unit["lon"])
		var lat := float(unit["lat"])
		var height := 0.03
		if _terrain_mode:
			if _is_tactical_overview():
				height = _designed_height_m(lon, lat) / 1000.0 * TACTICAL_OVERVIEW_RELIEF_EXAGGERATION + 0.06
			else:
				height = _designed_height_m(lon, lat) / 1000.0 + 0.012

		node.position = _geo_to_local(lon, lat, height)
		node.scale = Vector3.ONE * scale_value
		_orient_unit_hull_to_target(node, unit)

		var model := _get_unit_model_node(node)
		var marker := node.get_node_or_null("MapMarker")
		var selection := node.get_node_or_null("Selection")
		var marker_lod := uses_unit_marker_lod()
		if not alive:
			_apply_wreck_visual(node)
			if model != null:
				model.visible = _terrain_mode
			if marker != null:
				marker.visible = false
			if selection != null:
				selection.visible = false
			continue
		if model != null:
			model.visible = _terrain_mode and not marker_lod
		if marker != null:
			marker.visible = _terrain_mode and marker_lod
		if selection != null:
			var logical_id := str(unit.get("logical_unit_id", ""))
			var logical_selected: bool = not logical_id.is_empty() and logical_id in _selected_logical_unit_ids
			var is_selected: bool = i in _selected_unit_indices or logical_selected
			var is_primary: bool = (i in _selected_unit_indices and i == _selected_unit_index)
			if logical_selected and not _selected_logical_unit_ids.is_empty():
				is_primary = logical_id == _selected_logical_unit_ids.back()
			selection.visible = is_selected
			var selection_count: int = maxi(_selected_unit_indices.size(), _selected_logical_unit_ids.size())
			var ring_scale: float = 1.28 if is_primary else (0.92 if is_selected and selection_count > 1 else 1.0)
			selection.scale = Vector3.ONE * ring_scale


func _local_to_geo(local_position: Vector3) -> Vector2:
	var lat := _origin_lat - rad_to_deg(local_position.z / EARTH_RADIUS_KM)
	var mean_lat := deg_to_rad((lat + _origin_lat) * 0.5)
	var lon_radius := EARTH_RADIUS_KM * maxf(0.15, cos(mean_lat))
	var lon := _origin_lon + rad_to_deg(local_position.x / lon_radius)
	return Vector2(
		clampf(lon, REGION_WEST, REGION_EAST),
		clampf(lat, REGION_SOUTH, REGION_NORTH)
	)


func get_radar_action_mode() -> String:
	return _radar_action_mode


func set_radar_action_mode(mode: String) -> void:
	if mode in ["camera", "move", "select"]:
		_radar_action_mode = mode
	else:
		_radar_action_mode = "camera"
	_update_radar_mode_ui()


func toggle_radar_action_mode() -> void:
	set_radar_action_mode("move" if _radar_action_mode == "camera" else "camera")


func cycle_radar_action_mode() -> void:
	match _radar_action_mode:
		"camera": set_radar_action_mode("move")
		"move": set_radar_action_mode("select")
		_: set_radar_action_mode("camera")


func _update_radar_mode_ui() -> void:
	var button := get_node_or_null("HUD/CommandBar/Row/RadarModeButton") as Button
	if button == null:
		return
	match _radar_action_mode:
		"move": button.text = "RADAR MOVE"
		"select": button.text = "RADAR SELECT"
		_: button.text = "RADAR CAMERA"


func get_wreck_count() -> int:
	var count := 0
	for unit in _units:
		if bool(unit.get("alive", true)):
			continue
		var node = unit.get("node")
		if node is Node3D and is_instance_valid(node) and bool(node.get_meta("is_wreck", false)):
			count += 1
	return count


func get_radar_units() -> Array:
	var result: Array = []
	for i in range(_units.size()):
		if not _is_unit_selectable(i):
			continue
		var unit: Dictionary = _units[i]
		var u := clampf((float(unit["lon"]) - REGION_WEST) / (REGION_EAST - REGION_WEST), 0.0, 1.0)
		var v := clampf((REGION_NORTH - float(unit["lat"])) / (REGION_NORTH - REGION_SOUTH), 0.0, 1.0)
		result.append({
			"index": i,
			"uv": Vector2(u, v),
			"color": _army_color(i),
			"selected": i in _selected_unit_indices,
			"primary": i == _selected_unit_index,
		})
	return result


func select_nearest_unit_uv(uv: Vector2, max_distance: float = 0.06) -> int:
	var target := Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0))
	var best_index := -1
	var best_distance := maxf(0.0, max_distance)
	for raw_item in get_radar_units():
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item
		var point: Vector2 = item.get("uv", Vector2.ZERO)
		var distance := point.distance_to(target)
		if distance <= best_distance:
			best_distance = distance
			best_index = int(item.get("index", -1))
	if best_index >= 0:
		select_unit(best_index, false)
	return best_index


func get_radar_camera_uv() -> Vector2:
	return Vector2(
		clampf((_center_lon - REGION_WEST) / (REGION_EAST - REGION_WEST), 0.0, 1.0),
		clampf((REGION_NORTH - _center_lat) / (REGION_NORTH - REGION_SOUTH), 0.0, 1.0)
	)


func get_radar_camera_rect_uv() -> Rect2:
	var center := get_radar_camera_uv()
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := maxf(0.2, float(viewport_size.x) / maxf(1.0, float(viewport_size.y)))
	var half_height_km := 1.0
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		half_height_km = maxf(0.1, camera.size * 0.5)
	else:
		var camera_height_km := maxf(0.2, absf(camera.global_position.y))
		half_height_km = maxf(0.1, camera_height_km * tan(deg_to_rad(camera.fov * 0.5)))
	var half_width_km := half_height_km * aspect
	var half_lat_deg := rad_to_deg(half_height_km / EARTH_RADIUS_KM)
	var lon_radius := EARTH_RADIUS_KM * maxf(0.15, cos(deg_to_rad(_center_lat)))
	var half_lon_deg := rad_to_deg(half_width_km / lon_radius)
	var size_uv := Vector2(
		clampf((half_lon_deg * 2.0) / (REGION_EAST - REGION_WEST), 0.01, 1.0),
		clampf((half_lat_deg * 2.0) / (REGION_NORTH - REGION_SOUTH), 0.01, 1.0)
	)
	var position := center - size_uv * 0.5
	position.x = clampf(position.x, 0.0, 1.0 - size_uv.x)
	position.y = clampf(position.y, 0.0, 1.0 - size_uv.y)
	return Rect2(position, size_uv)


func get_rts_zoom_level() -> int:
	return _rts_zoom_level


func radar_center_on_uv(uv: Vector2) -> void:
	uv.x = clampf(uv.x, 0.0, 1.0)
	uv.y = clampf(uv.y, 0.0, 1.0)
	_center_lon = lerpf(REGION_WEST, REGION_EAST, uv.x)
	_center_lat = lerpf(REGION_NORTH, REGION_SOUTH, uv.y)
	_position_camera()
	_refresh_tiles()
	_sync_unit_visuals()
	_refresh_geo_overlay(true)
	_update_status()
	if _terrain_mode and not _is_tactical_overview():
		call_deferred("_refresh_vector_data", true)


func _screen_to_ground(screen_position: Vector2):
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var ground_plane := Plane(Vector3.UP, 0.0)
	return ground_plane.intersects_ray(ray_origin, ray_direction)


func pick_detail_logical_id_from_screen(screen_position: Vector2) -> String:
	if _rts_zoom_level < RTS_DETAIL_UNIT_LOD_MIN:
		return ""
	var closest_id := ""
	var closest_distance := UNIT_SELECT_RADIUS_PX
	for node in _detail_unit_nodes:
		if not is_instance_valid(node) or not node.visible or bool(node.get_meta("logical_wreck", false)):
			continue
		if camera.is_position_behind(node.global_position):
			continue
		var logical_id := str(node.get_meta("logical_unit_id", ""))
		if logical_id.is_empty():
			continue
		var unit_screen := camera.unproject_position(node.global_position)
		var distance := unit_screen.distance_to(screen_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_id = logical_id
	return closest_id


func _handle_world_tap(screen_position: Vector2) -> void:
	if _units.is_empty():
		return

	var detail_logical_id := pick_detail_logical_id_from_screen(screen_position)
	if not detail_logical_id.is_empty():
		clear_selected_units()
		toggle_logical_heavy_selection(detail_logical_id)
		return

	var closest_index := -1
	var closest_distance := UNIT_SELECT_RADIUS_PX
	for i in range(_units.size()):
		if not _is_unit_selectable(i):
			continue
		var unit: Dictionary = _units[i]
		var node: Node3D = unit["node"]
		if camera.is_position_behind(node.global_position):
			continue
		var unit_screen := camera.unproject_position(node.global_position)
		var distance := unit_screen.distance_to(screen_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = i

	if closest_index >= 0:
		if _rts_zoom_level >= RTS_DETAIL_UNIT_LOD_MIN:
			var closest_unit: Dictionary = _units[closest_index]
			var logical_id := str(closest_unit.get("logical_unit_id", ""))
			if not logical_id.is_empty():
				clear_selected_units()
				toggle_logical_heavy_selection(logical_id)
				return
		select_unit(closest_index, true)
		return

	if not _selected_logical_unit_ids.is_empty():
		var logical_ground_hit = _screen_to_ground(screen_position)
		if logical_ground_hit != null:
			var logical_destination = _local_to_geo(logical_ground_hit)
			if issue_selected_logical_group_move(logical_destination) > 0:
				_update_status()
				return

	if not _selected_unit_indices.is_empty():
		var ground_hit = _screen_to_ground(screen_position)
		if ground_hit != null:
			var destination = _local_to_geo(ground_hit)
			if issue_selected_group_move(destination):
				_update_status()
				return

	clear_selection_on_empty_ground()


func clear_selection_on_empty_ground() -> bool:
	var had_selection := not _selected_unit_indices.is_empty() or not _selected_logical_unit_ids.is_empty()
	clear_selected_units()
	clear_logical_heavy_selection()
	return had_selection


func _toggle_unit_selection(unit_index: int) -> void:
	if not _is_unit_selectable(unit_index):
		return
	if unit_index in _selected_unit_indices:
		_selected_unit_indices.erase(unit_index)
	else:
		_selected_unit_indices.append(unit_index)
	_selected_unit_index = _selected_unit_indices.back() if not _selected_unit_indices.is_empty() else -1
	_sync_unit_visuals()
	_update_status()


func _is_unit_selectable(index: int) -> bool:
	if index < 0 or index >= _units.size():
		return false
	var unit: Dictionary = _units[index]
	if not bool(unit.get("alive", true)):
		return false
	var node = unit.get("node")
	return node is Node3D and is_instance_valid(node)


func select_unit(index: int, additive: bool = false) -> bool:
	if not _is_unit_selectable(index):
		return false
	if additive:
		toggle_unit_selection(index)
	else:
		select_single_unit(index)
	return index in _selected_unit_indices


func select_units(indices: Array[int]) -> void:
	_selected_unit_indices.clear()
	for index in indices:
		if not _is_unit_selectable(index):
			continue
		if index not in _selected_unit_indices:
			_selected_unit_indices.append(index)
	_selected_unit_index = _selected_unit_indices.back() if not _selected_unit_indices.is_empty() else -1
	_sync_unit_visuals()
	_update_status()


func toggle_unit_selection(index: int) -> void:
	if not _is_unit_selectable(index):
		return
	_toggle_unit_selection(index)


func select_single_unit(index: int) -> void:
	var indices: Array[int] = []
	if _is_unit_selectable(index):
		indices.append(index)
	select_units(indices)


func select_previous_unit() -> void:
	if _units.is_empty():
		clear_selected_units()
		return
	var start := _selected_unit_index if _selected_unit_index >= 0 else 0
	for step in range(1, _units.size() + 1):
		var index := posmod(start - step, _units.size())
		if _is_unit_selectable(index):
			select_single_unit(index)
			return
	clear_selected_units()


func select_next_unit() -> void:
	if _units.is_empty():
		clear_selected_units()
		return
	var start := _selected_unit_index
	for step in range(1, _units.size() + 1):
		var index := posmod(start + step, _units.size())
		if _is_unit_selectable(index):
			select_single_unit(index)
			return
	clear_selected_units()


func select_all_units() -> void:
	var indices: Array[int] = []
	for i in range(_units.size()):
		if _is_unit_selectable(i):
			indices.append(i)
	select_units(indices)


func clear_selected_units() -> void:
	_selected_unit_indices.clear()
	_selected_unit_index = -1
	_sync_unit_visuals()
	_update_status()


func get_selected_unit_indices() -> Array[int]:
	return _selected_unit_indices.duplicate()


func get_selected_unit_count() -> int:
	return _selected_unit_indices.size()


func clear_logical_heavy_selection() -> void:
	_selected_logical_unit_ids.clear()
	_sync_unit_visuals()
	_sync_detail_unit_lod()
	_update_status()


func get_selected_logical_heavy_ids() -> Array[String]:
	return _selected_logical_unit_ids.duplicate()


func get_selected_logical_heavy_count() -> int:
	return _selected_logical_unit_ids.size()


func select_logical_heavy_units_in_screen_rect(screen_rect: Rect2, additive: bool = false) -> int:
	var game_state := _game_state_node()
	if game_state == null or camera == null:
		return 0
	var normalized := screen_rect.abs()
	if normalized.size.x <= 1.0 or normalized.size.y <= 1.0:
		return 0
	if not additive:
		_selected_logical_unit_ids.clear()

	var candidate_ids := {}
	for raw_unit in _units:
		var unit: Dictionary = raw_unit
		var logical_id := str(unit.get("logical_unit_id", ""))
		var node = unit.get("node")
		if logical_id.is_empty() or not (node is Node3D) or not is_instance_valid(node):
			continue
		if not bool(unit.get("alive", true)) or not node.visible or camera.is_position_behind(node.global_position):
			continue
		var screen_point := camera.unproject_position(node.global_position)
		if normalized.has_point(screen_point):
			candidate_ids[logical_id] = true

	if _rts_zoom_level >= RTS_DETAIL_UNIT_LOD_MIN:
		for node in _detail_unit_nodes:
			if not is_instance_valid(node) or not node.visible or bool(node.get_meta("logical_wreck", false)) or camera.is_position_behind(node.global_position):
				continue
			var logical_id := str(node.get_meta("logical_unit_id", ""))
			if logical_id.is_empty():
				continue
			var screen_point := camera.unproject_position(node.global_position)
			if normalized.has_point(screen_point):
				candidate_ids[logical_id] = true

	for logical_id in candidate_ids.keys():
		var logical: Dictionary = game_state.call("get_heavy_unit", str(logical_id))
		if logical.is_empty() or not bool(logical.get("alive", true)):
			continue
		if str(logical_id) not in _selected_logical_unit_ids:
			_selected_logical_unit_ids.append(str(logical_id))

	_sync_unit_visuals()
	_sync_detail_unit_lod()
	_update_status()
	return _selected_logical_unit_ids.size()


func select_logical_heavy_unit(unit_id: String, additive: bool = false) -> bool:
	var game_state := _game_state_node()
	if game_state == null:
		return false
	var logical: Dictionary = game_state.call("get_heavy_unit", unit_id)
	if logical.is_empty() or not bool(logical.get("alive", true)):
		return false
	if not additive:
		_selected_logical_unit_ids.clear()
	if unit_id not in _selected_logical_unit_ids:
		_selected_logical_unit_ids.append(unit_id)
	_sync_unit_visuals()
	_sync_detail_unit_lod()
	_update_status()
	return true


func toggle_logical_heavy_selection(unit_id: String) -> bool:
	var game_state := _game_state_node()
	if game_state == null:
		return false
	var logical: Dictionary = game_state.call("get_heavy_unit", unit_id)
	if logical.is_empty() or not bool(logical.get("alive", true)):
		return false
	if unit_id in _selected_logical_unit_ids:
		_selected_logical_unit_ids.erase(unit_id)
	else:
		_selected_logical_unit_ids.append(unit_id)
	_sync_unit_visuals()
	_sync_detail_unit_lod()
	_update_status()
	return true



func add_logical_heavy_ids(unit_ids: Array) -> int:
	var game_state := _game_state_node()
	if game_state == null:
		return 0
	var added_count: int = 0
	for raw_id in unit_ids:
		var logical_id: String = str(raw_id)
		if logical_id.is_empty() or logical_id in _selected_logical_unit_ids:
			continue
		var logical: Dictionary = game_state.call("get_heavy_unit", logical_id)
		if logical.is_empty() or not bool(logical.get("alive", true)):
			continue
		_selected_logical_unit_ids.append(logical_id)
		added_count += 1
	_sync_unit_visuals()
	_sync_detail_unit_lod()
	_update_status()
	return added_count

func select_governorate_logical_heavy_units(governorate_index: int, unit_type: String = "", quantity: int = -1) -> int:
	var game_state := _game_state_node()
	if game_state == null or governorate_index < 0 or governorate_index >= GOVERNORATES.size():
		return 0
	var roster_units: Array = game_state.call("get_heavy_units_for_governorate", governorate_index, true)
	_selected_logical_unit_ids.clear()
	for raw_unit in roster_units:
		var logical: Dictionary = raw_unit
		if not unit_type.is_empty() and str(logical.get("unit_type", "")) != unit_type:
			continue
		var logical_id := str(logical.get("id", ""))
		if logical_id.is_empty():
			continue
		_selected_logical_unit_ids.append(logical_id)
		if quantity > 0 and _selected_logical_unit_ids.size() >= quantity:
			break
	_sync_unit_visuals()
	_sync_detail_unit_lod()
	_update_status()
	return _selected_logical_unit_ids.size()




func select_governorate_force_mix(governorate_index: int, tanks: int, artillery: int, launchers: int) -> int:
	var game_state := _game_state_node()
	if game_state == null or governorate_index < 0 or governorate_index >= GOVERNORATES.size():
		return 0
	var requested := {
		"tank": maxi(0, tanks),
		"artillery": maxi(0, artillery),
		"rocket_launcher": maxi(0, launchers),
	}
	var remaining := requested.duplicate()
	_selected_logical_unit_ids.clear()
	var roster_units: Array = game_state.call("get_heavy_units_for_governorate", governorate_index, true)
	for raw_unit in roster_units:
		var logical: Dictionary = raw_unit
		var unit_type: String = str(logical.get("unit_type", ""))
		if not remaining.has(unit_type) or int(remaining[unit_type]) <= 0:
			continue
		var logical_id: String = str(logical.get("id", ""))
		if logical_id.is_empty():
			continue
		_selected_logical_unit_ids.append(logical_id)
		remaining[unit_type] = int(remaining[unit_type]) - 1
	var expected: int = int(requested["tank"]) + int(requested["artillery"]) + int(requested["rocket_launcher"])
	if _selected_logical_unit_ids.size() != expected:
		_selected_logical_unit_ids.clear()
		return 0
	_sync_unit_visuals()
	_sync_detail_unit_lod()
	_update_status()
	return _selected_logical_unit_ids.size()

func issue_selected_logical_group_move(destination: Vector2) -> int:
	if _selected_logical_unit_ids.is_empty() or not _is_move_destination_valid(destination):
		return 0
	var game_state := _game_state_node()
	if game_state == null:
		return 0
	destination = Vector2(
		clampf(destination.x, REGION_WEST, REGION_EAST),
		clampf(destination.y, REGION_SOUTH, REGION_NORTH)
	)
	_move_order_serial += 1
	var issued_count: int = 0
	var columns: int = maxi(1, int(ceil(sqrt(float(_selected_logical_unit_ids.size())))))
	var rows: int = int(ceil(float(_selected_logical_unit_ids.size()) / float(columns)))
	for order_index in range(_selected_logical_unit_ids.size()):
		var row: int = int(order_index / columns)
		var column: int = order_index % columns
		var centered_column: float = float(column) - float(columns - 1) * 0.5
		var centered_row: float = float(row) - float(rows - 1) * 0.5
		var east_km: float = centered_column * GROUP_FORMATION_SPACING_KM
		var north_km: float = -centered_row * GROUP_FORMATION_SPACING_KM
		var target_lat: float = destination.y + rad_to_deg(north_km / EARTH_RADIUS_KM)
		var lon_radius: float = EARTH_RADIUS_KM * maxf(0.15, cos(deg_to_rad(destination.y)))
		var target_lon: float = destination.x + rad_to_deg(east_km / lon_radius)
		var target := Vector2(
			clampf(target_lon, REGION_WEST, REGION_EAST),
			clampf(target_lat, REGION_SOUTH, REGION_NORTH)
		)
		var logical_id: String = _selected_logical_unit_ids[order_index]
		var representative_index: int = -1
		for visible_index in range(_units.size()):
			var visible_unit: Dictionary = _units[visible_index]
			if str(visible_unit.get("logical_unit_id", "")) == logical_id:
				representative_index = visible_index
				break
		if representative_index >= 0:
			if _issue_move_order(representative_index, target):
				issued_count += 1
		elif bool(game_state.call("issue_heavy_move", logical_id, target.x, target.y)):
			issued_count += 1
	return issued_count


func stop_selected_logical_heavy_units() -> int:
	if _selected_logical_unit_ids.is_empty():
		return 0
	var game_state := _game_state_node()
	if game_state == null:
		return 0
	var stopped_count: int = 0
	for logical_id in _selected_logical_unit_ids:
		var representative_index: int = -1
		for visible_index in range(_units.size()):
			var visible_unit: Dictionary = _units[visible_index]
			if str(visible_unit.get("logical_unit_id", "")) == logical_id:
				representative_index = visible_index
				break
		if representative_index >= 0:
			var unit: Dictionary = _units[representative_index]
			unit["moving"] = false
			unit["target_lon"] = float(unit.get("lon", 0.0))
			unit["target_lat"] = float(unit.get("lat", 0.0))
			_units[representative_index] = unit
		if bool(game_state.call("stop_heavy_unit", logical_id)):
			stopped_count += 1
	_sync_unit_visuals()
	_sync_detail_unit_lod()
	return stopped_count

func focus_selected_units() -> bool:
	var lon_sum := 0.0
	var lat_sum := 0.0
	var count := 0
	for index in _selected_unit_indices:
		if index < 0 or index >= _units.size():
			continue
		var unit: Dictionary = _units[index]
		if not bool(unit.get("alive", true)):
			continue
		lon_sum += float(unit["lon"])
		lat_sum += float(unit["lat"])
		count += 1
	if count == 0:
		return false
	_center_lon = clampf(lon_sum / float(count), REGION_WEST, REGION_EAST)
	_center_lat = clampf(lat_sum / float(count), REGION_SOUTH, REGION_NORTH)
	_origin_lon = _center_lon
	_origin_lat = _center_lat
	_position_camera()
	_sync_unit_visuals()
	_update_status()
	return true



func focus_selected_logical_heavy_units() -> bool:
	if _selected_logical_unit_ids.is_empty():
		return false
	var game_state := _game_state_node()
	if game_state == null:
		return false
	var lon_sum: float = 0.0
	var lat_sum: float = 0.0
	var count: int = 0
	for logical_id in _selected_logical_unit_ids:
		var logical: Dictionary = game_state.call("get_heavy_unit", logical_id)
		if logical.is_empty() or not bool(logical.get("alive", true)):
			continue
		lon_sum += float(logical.get("lon", 0.0))
		lat_sum += float(logical.get("lat", 0.0))
		count += 1
	if count <= 0:
		return false
	_center_lon = clampf(lon_sum / float(count), REGION_WEST, REGION_EAST)
	_center_lat = clampf(lat_sum / float(count), REGION_SOUTH, REGION_NORTH)
	_origin_lon = _center_lon
	_origin_lat = _center_lat
	_position_camera()
	_sync_unit_visuals()
	_sync_detail_unit_lod()
	_update_status()
	return true

func issue_selected_group_move(destination: Vector2) -> bool:
	return _issue_group_move_order(_selected_unit_indices, destination)


func issue_selected_group_move_uv(uv: Vector2) -> bool:
	var clamped := Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0))
	var destination := Vector2(
		lerpf(REGION_WEST, REGION_EAST, clamped.x),
		lerpf(REGION_NORTH, REGION_SOUTH, clamped.y)
	)
	return _issue_group_move_order(_selected_unit_indices, destination)


func get_selected_move_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	for index in _selected_unit_indices:
		if index < 0 or index >= _units.size():
			continue
		var unit: Dictionary = _units[index]
		targets.append(Vector2(float(unit.get("target_lon", unit["lon"])), float(unit.get("target_lat", unit["lat"]))))
	return targets


func stop_selected_units() -> int:
	var stopped_count := 0
	for index in _selected_unit_indices:
		if index < 0 or index >= _units.size():
			continue
		var unit: Dictionary = _units[index]
		if bool(unit.get("moving", false)):
			stopped_count += 1
		var logical_id := str(unit.get("logical_unit_id", ""))
		if not logical_id.is_empty():
			var game_state := _game_state_node()
			if game_state != null:
				game_state.call(
					"update_heavy_unit_position",
					logical_id,
					float(unit.get("lon", 0.0)),
					float(unit.get("lat", 0.0))
				)
				game_state.call("stop_heavy_unit", logical_id)
		unit["moving"] = false
		unit["target_lon"] = float(unit["lon"])
		unit["target_lat"] = float(unit["lat"])
		_units[index] = unit
	return stopped_count


func are_selected_units_stopped() -> bool:
	for index in _selected_unit_indices:
		if index < 0 or index >= _units.size():
			continue
		if bool(_units[index].get("moving", false)):
			return false
	return true


func _is_move_destination_valid(destination: Vector2) -> bool:
	return (
		destination.x == destination.x
		and destination.y == destination.y
		and absf(destination.x) < 1000.0
		and absf(destination.y) < 1000.0
	)


func _issue_group_move_order(unit_indices: Array[int], destination: Vector2) -> bool:
	if unit_indices.is_empty() or not _is_move_destination_valid(destination):
		return false
	destination = Vector2(
		clampf(destination.x, REGION_WEST, REGION_EAST),
		clampf(destination.y, REGION_SOUTH, REGION_NORTH)
	)
	_move_order_serial += 1
	var issued_count := 0
	var columns := maxi(1, int(ceil(sqrt(float(unit_indices.size())))))
	for order_index in range(unit_indices.size()):
		var row := int(order_index / columns)
		var column := order_index % columns
		var centered_column := float(column) - float(columns - 1) * 0.5
		var rows := int(ceil(float(unit_indices.size()) / float(columns)))
		var centered_row := float(row) - float(rows - 1) * 0.5
		var east_km := centered_column * GROUP_FORMATION_SPACING_KM
		var north_km := -centered_row * GROUP_FORMATION_SPACING_KM
		var target_lat := destination.y + rad_to_deg(north_km / EARTH_RADIUS_KM)
		var lon_radius := EARTH_RADIUS_KM * maxf(0.15, cos(deg_to_rad(destination.y)))
		var target_lon := destination.x + rad_to_deg(east_km / lon_radius)
		if _issue_move_order(
			unit_indices[order_index],
			Vector2(
				clampf(target_lon, REGION_WEST, REGION_EAST),
				clampf(target_lat, REGION_SOUTH, REGION_NORTH)
			)
		):
			issued_count += 1
	return issued_count > 0


func _issue_move_order(unit_index: int, destination: Vector2) -> bool:
	if unit_index < 0 or unit_index >= _units.size():
		return false
	var unit: Dictionary = _units[unit_index]
	var target_lon := clampf(destination.x, REGION_WEST, REGION_EAST)
	var target_lat := clampf(destination.y, REGION_SOUTH, REGION_NORTH)
	var logical_id := str(unit.get("logical_unit_id", ""))
	if not logical_id.is_empty():
		var game_state := _game_state_node()
		if game_state == null or not bool(game_state.call("issue_heavy_move", logical_id, target_lon, target_lat)):
			return false
	unit["target_lon"] = target_lon
	unit["target_lat"] = target_lat
	unit["move_order_serial"] = _move_order_serial
	unit["moving"] = true
	_units[unit_index] = unit
	return true


func _sync_logical_unit_position(unit: Dictionary) -> bool:
	var logical_id := str(unit.get("logical_unit_id", ""))
	if logical_id.is_empty():
		return false
	var game_state := _game_state_node()
	if game_state == null:
		return false
	var position_ok := bool(game_state.call(
		"update_heavy_unit_position",
		logical_id,
		float(unit.get("lon", 0.0)),
		float(unit.get("lat", 0.0))
	))
	var heading_ok := bool(game_state.call(
		"update_heavy_heading",
		logical_id,
		float(unit.get("heading_rad", 0.0))
	))
	return position_ok and heading_ok


func _process(delta: float) -> void:
	if _units.is_empty():
		return

	var representative_ids: Dictionary = {}
	for visible_unit in _units:
		var representative_id: String = str((visible_unit as Dictionary).get("logical_unit_id", ""))
		if not representative_id.is_empty():
			representative_ids[representative_id] = true

	var logical_moved_count: int = 0
	var roster_state := _game_state_node()
	if roster_state != null:
		logical_moved_count = int(roster_state.call("tick_heavy_force_movement", delta, representative_ids))

	var any_moved := false
	for i in range(_units.size()):
		var unit: Dictionary = _units[i]
		if not bool(unit.get("moving", false)):
			continue

		var current := _geo_to_local(float(unit["lon"]), float(unit["lat"]), 0.0)
		var target := _geo_to_local(float(unit["target_lon"]), float(unit["target_lat"]), 0.0)
		var flat_delta := Vector2(target.x - current.x, target.z - current.z)
		var distance_km := flat_delta.length()
		if distance_km > 0.000001:
			unit["heading_rad"] = atan2(-flat_delta.x, -flat_delta.y)
		var speed_km_per_sec: float = maxf(0.0, float(unit.get("speed_km_sec", UNIT_SPEED_KM_PER_SEC)))
		var step_km := speed_km_per_sec * delta

		if distance_km <= maxf(0.001, step_km):
			unit["lon"] = float(unit["target_lon"])
			unit["lat"] = float(unit["target_lat"])
			unit["moving"] = false
		else:
			var ratio := step_km / distance_km
			var next_local := Vector3(
				lerpf(current.x, target.x, ratio),
				0.0,
				lerpf(current.z, target.z, ratio)
			)
			var next_geo := _local_to_geo(next_local)
			unit["lon"] = next_geo.x
			unit["lat"] = next_geo.y

		_units[i] = unit
		_sync_logical_unit_position(unit)
		if not bool(unit.get("moving", false)):
			var logical_id := str(unit.get("logical_unit_id", ""))
			var game_state := _game_state_node()
			if not logical_id.is_empty() and game_state != null:
				game_state.call("stop_heavy_unit", logical_id)
		any_moved = true

	if any_moved:
		_sync_unit_visuals()
	if logical_moved_count > 0:
		_sync_detail_unit_lod()

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


func focus_governorate_from_clock(index: int) -> bool:
	if index < 0 or index >= GOVERNORATES.size():
		return false
	_select_governorate(index)
	return true


func _select_governorate(index: int) -> void:
	_governorate_index = posmod(index, GOVERNORATES.size())
	_sync_province_clock_selection()
	var gov := _governorate()
	_center_lon = float(gov["lon"])
	_center_lat = float(gov["lat"])
	_map_zoom = MAX_MAP_ZOOM if _terrain_mode else DEFAULT_MAP_ZOOM
	if not _terrain_mode:
		_map_zoom_before_terrain = _map_zoom
	zoom_wheel.set_value_no_signal(float(_map_zoom))

	_update_governorate_ui()
	_position_camera()
	_sync_detail_unit_lod(true)
	_refresh_tiles()
	_update_status()

	if _terrain_mode and not _is_tactical_overview():
		call_deferred("_refresh_vector_data", true)
	_refresh_geo_overlay(true)


func _on_select_all_units_pressed() -> void:
	select_all_units()


func _on_box_select_pressed() -> void:
	_box_select_mode = not _box_select_mode
	if not _box_select_mode:
		_box_select_active = false
		_box_select_pointer_id = -1
		if selection_box != null:
			selection_box.visible = false
	var button := get_node_or_null("HUD/CommandBar/Row/BoxSelectButton") as Button
	if button != null:
		button.text = "BOX ACTIVE" if _box_select_mode else "BOX SELECT"
	_update_status()


func _on_clear_selection_pressed() -> void:
	clear_selected_units()
	clear_logical_heavy_selection()


func _on_previous_unit_pressed() -> void:
	select_previous_unit()


func _on_next_unit_pressed() -> void:
	select_next_unit()


func _on_focus_units_pressed() -> void:
	if not _selected_logical_unit_ids.is_empty():
		focus_selected_logical_heavy_units()
	else:
		focus_selected_units()


func _on_stop_units_pressed() -> void:
	if not _selected_logical_unit_ids.is_empty():
		stop_selected_logical_heavy_units()
	else:
		stop_selected_units()


func _on_radar_mode_pressed() -> void:
	cycle_radar_action_mode()


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
		_commit_vector_batch(road_shoulders, "RoadShoulderBatch", Color(0.45, 0.35, 0.22, 1.0))
		_commit_vector_batch(roads, "RoadBatch", Color(0.70, 0.59, 0.40, 1.0))
	if _building_feature_count > 0:
		_commit_vector_batch(buildings, "BuildingBatch", Color(0.76, 0.68, 0.59, 1.0))
	if _water_feature_count > 0:
		_commit_vector_batch(water_banks, "WaterBankBatch", Color(0.47, 0.39, 0.25, 1.0))
		_commit_vector_batch(water, "WaterBatch", Color(0.07, 0.34, 0.43, 1.0))

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
			return Color(0.16, 0.31, 0.10, 1.0)
		"orchard":
			return Color(0.27, 0.39, 0.12, 1.0)
		"farmland":
			return Color(0.55, 0.47, 0.24, 1.0)
		"meadow":
			return Color(0.31, 0.46, 0.18, 1.0)
		"scrub":
			return Color(0.39, 0.39, 0.20, 1.0)
		"park":
			return Color(0.22, 0.43, 0.14, 1.0)
		_:
			return Color(0.46, 0.42, 0.23, 1.0)


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
	return _designed_height_m(lon, lat) / 1000.0


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
	_clear_strategic_world()
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


func _update_command_buttons_state() -> void:
	var has_selection := not _selected_unit_indices.is_empty() or not _selected_logical_unit_ids.is_empty()
	var clear_button := get_node_or_null("HUD/CommandBar/Row/ClearSelectionButton") as Button
	var focus_button := get_node_or_null("HUD/CommandBar/Row/FocusUnitsButton") as Button
	var stop_button := get_node_or_null("HUD/CommandBar/Row/StopUnitsButton") as Button
	if clear_button != null:
		clear_button.disabled = not has_selection
	if focus_button != null:
		focus_button.disabled = not has_selection
	if stop_button != null:
		stop_button.disabled = not has_selection


func _update_status() -> void:
	if _terrain_mode:
		zoom_label.text = "RTS CAMERA • %dX" % _rts_zoom_level
	else:
		if _map_zoom <= SYRIA_OVERVIEW_ZOOM:
			zoom_label.text = "SYRIA • STRATEGIC"
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
			status_label.text = "SYRIA STRATEGIC READY" if _is_strategic_map() else "%s MAP READY" % _governorate_name()

	var selected_count := maxi(_selected_unit_indices.size(), _selected_logical_unit_ids.size())
	if selected_count > 0:
		status_label.text += " • SELECTED %d" % selected_count
	_update_command_buttons_state()



func _on_zoom_in_pressed() -> void:
	_set_rts_zoom_level(_rts_zoom_level + 1)


func _on_zoom_out_pressed() -> void:
	_set_rts_zoom_level(_rts_zoom_level - 1)


func _on_zoom_wheel_changed(value: float) -> void:
	_set_rts_zoom_level(clampi(int(round(value)), RTS_ZOOM_LEVEL_MIN, RTS_ZOOM_LEVEL_MAX))


func _on_reset_pressed() -> void:
	var gov := _governorate()
	_center_lon = float(gov["lon"])
	_center_lat = float(gov["lat"])
	if _terrain_mode:
		_map_zoom = MAX_MAP_ZOOM
		_rts_zoom_level = RTS_ZOOM_LEVEL_MIN
	else:
		_map_zoom = DEFAULT_MAP_ZOOM
		_map_zoom_before_terrain = _map_zoom
	zoom_wheel.set_value_no_signal(float(_rts_zoom_level if _terrain_mode else _map_zoom))
	_position_camera()
	_refresh_tiles()
	if _terrain_mode and not _is_tactical_overview():
		_refresh_vector_data(true)
	_sync_unit_visuals()
	_refresh_geo_overlay(true)
	_update_status()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
