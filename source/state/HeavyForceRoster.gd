class_name HeavyForceRoster
extends RefCounted

const FORCE_TEMPLATE := {
	"tank": 50,
	"rocket_launcher": 20,
	"artillery": 30,
}
const UNIT_ORDER := ["tank", "rocket_launcher", "artillery"]
const ROUTE_CURRENT_EPSILON_KM := 0.00001
const ROUTE_DUPLICATE_EPSILON_KM := 0.0005

var _units: Array[Dictionary] = []
var _index_by_id: Dictionary = {}
var _seeded := false


func is_seeded() -> bool:
	return _seeded


func seed(governorates: Array, unit_specs: Dictionary) -> bool:
	if _seeded:
		return true
	if governorates.size() != 14:
		return false

	for governorate_index in range(governorates.size()):
		var gov: Dictionary = governorates[governorate_index]
		var base_lon := float(gov.get("lon", 0.0))
		var base_lat := float(gov.get("lat", 0.0))
		for unit_type in UNIT_ORDER:
			var quantity := int(FORCE_TEMPLATE[unit_type])
			var spec: Dictionary = unit_specs.get(unit_type, {})
			var max_hp := maxf(1.0, float(spec.get("hp", 100.0)))
			var speed_km_sec := maxf(0.0, float(spec.get("speed_km_sec", 0.0)))
			for slot in range(quantity):
				var unit_id := "G%02d-%s-%03d" % [governorate_index + 1, unit_type, slot + 1]
				var spread := _spawn_offset(unit_type, slot, quantity)
				var unit := {
					"id": unit_id,
					"home_governorate_index": governorate_index,
					"current_governorate_index": governorate_index,
					"unit_type": unit_type,
					"slot": slot,
					"lon": base_lon + spread.x,
					"lat": base_lat + spread.y,
					"target_lon": base_lon + spread.x,
					"target_lat": base_lat + spread.y,
					"moving": false,
					"heading_rad": 0.0,
					"alive": true,
					"hp": max_hp,
					"max_hp": max_hp,
					"speed_km_sec": speed_km_sec,
				}
				_index_by_id[unit_id] = _units.size()
				_units.append(unit)

	_seeded = _units.size() == 1400
	return _seeded


func get_total_count() -> int:
	return _units.size()


func get_units_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit in _units:
		result.append(unit.duplicate(true))
	return result


func _spawn_offset(unit_type: String, slot: int, quantity: int) -> Vector2:
	var columns := 10
	var rows := maxi(1, int(ceil(float(quantity) / float(columns))))
	var column := slot % columns
	var row := int(slot / columns)
	var x := (float(column) - float(columns - 1) * 0.5) * 0.006
	var y := (float(row) - float(rows - 1) * 0.5) * 0.006
	match unit_type:
		"rocket_launcher":
			x -= 0.035
		"artillery":
			x += 0.035
	return Vector2(x, y)


func count_type(unit_type: String, alive_only: bool = false) -> int:
	var count := 0
	for unit in _units:
		if str(unit.get("unit_type", "")) != unit_type:
			continue
		if alive_only and not bool(unit.get("alive", true)):
			continue
		count += 1
	return count


func count_governorate(governorate_index: int, alive_only: bool = false) -> int:
	var count := 0
	for unit in _units:
		if int(unit.get("current_governorate_index", -1)) != governorate_index:
			continue
		if alive_only and not bool(unit.get("alive", true)):
			continue
		count += 1
	return count


func get_unit(unit_id: String) -> Dictionary:
	if not _index_by_id.has(unit_id):
		return {}
	var index := int(_index_by_id[unit_id])
	if index < 0 or index >= _units.size():
		return {}
	return _units[index].duplicate(true)


func set_unit_position(unit_id: String, lon: float, lat: float) -> bool:
	if not _index_by_id.has(unit_id):
		return false
	var index := int(_index_by_id[unit_id])
	var unit: Dictionary = _units[index]
	unit["lon"] = lon
	unit["lat"] = lat
	_units[index] = unit
	return true


func issue_move(unit_id: String, target_lon: float, target_lat: float) -> bool:
	return issue_route(unit_id, [Vector2(target_lon, target_lat)])


func _route_distance_km(a: Vector2, b: Vector2) -> float:
	var mean_lat := deg_to_rad((a.y + b.y) * 0.5)
	var lon_km := (b.x - a.x) * 111.32 * maxf(0.15, cos(mean_lat))
	var lat_km := (b.y - a.y) * 111.32
	return sqrt(lon_km * lon_km + lat_km * lat_km)


func issue_route(unit_id: String, waypoints: Array) -> bool:
	if not _index_by_id.has(unit_id) or waypoints.is_empty():
		return false
	var index := int(_index_by_id[unit_id])
	var unit: Dictionary = _units[index]
	if not bool(unit.get("alive", true)):
		return false
	var normalized: Array = []
	for raw_point in waypoints:
		var point := Vector2.ZERO
		var valid_point := false
		if raw_point is Vector2:
			point = raw_point
			valid_point = true
		elif typeof(raw_point) == TYPE_DICTIONARY:
			var point_dict: Dictionary = raw_point
			if point_dict.has("lon") and point_dict.has("lat"):
				point = Vector2(float(point_dict["lon"]), float(point_dict["lat"]))
				valid_point = true
		if not valid_point:
			continue
		if absf(point.x) > 180.0 or absf(point.y) > 90.0:
			continue
		if not normalized.is_empty():
			var previous: Dictionary = normalized.back()
			var previous_point := Vector2(float(previous["lon"]), float(previous["lat"]))
			if _route_distance_km(previous_point, point) < ROUTE_DUPLICATE_EPSILON_KM:
				continue
		normalized.append({"lon": point.x, "lat": point.y})
	var current_point := Vector2(float(unit.get("lon", 0.0)), float(unit.get("lat", 0.0)))
	while not normalized.is_empty():
		var first_candidate: Dictionary = normalized[0]
		var candidate_point := Vector2(float(first_candidate["lon"]), float(first_candidate["lat"]))
		if _route_distance_km(current_point, candidate_point) >= ROUTE_CURRENT_EPSILON_KM:
			break
		normalized.pop_front()
	if normalized.is_empty():
		return false
	var first: Dictionary = normalized.pop_front()
	unit["target_lon"] = float(first["lon"])
	unit["target_lat"] = float(first["lat"])
	var start_lon := float(unit.get("lon", 0.0))
	var start_lat := float(unit.get("lat", 0.0))
	var lon_scale_km := maxf(1.0, 111.32 * cos(deg_to_rad(start_lat)))
	var delta_lon_km := (float(first["lon"]) - start_lon) * lon_scale_km
	var delta_lat_km := (float(first["lat"]) - start_lat) * 111.32
	if absf(delta_lon_km) + absf(delta_lat_km) > 0.000001:
		unit["heading_rad"] = atan2(-delta_lon_km, delta_lat_km)
	unit["route_points"] = normalized
	unit["moving"] = true
	_units[index] = unit
	return true


func get_pending_route_point_count(unit_id: String) -> int:
	if not _index_by_id.has(unit_id):
		return -1
	var index := int(_index_by_id[unit_id])
	var unit: Dictionary = _units[index]
	return (unit.get("route_points", []) as Array).size()


func stop_unit(unit_id: String) -> bool:
	if not _index_by_id.has(unit_id):
		return false
	var index := int(_index_by_id[unit_id])
	var unit: Dictionary = _units[index]
	unit["target_lon"] = float(unit.get("lon", 0.0))
	unit["target_lat"] = float(unit.get("lat", 0.0))
	unit["route_points"] = []
	unit["moving"] = false
	_units[index] = unit
	return true


func record_destroyed(unit_id: String) -> bool:
	if not _index_by_id.has(unit_id):
		return false
	var index := int(_index_by_id[unit_id])
	var unit: Dictionary = _units[index]
	if not bool(unit.get("alive", true)):
		return false
	unit["alive"] = false
	unit["hp"] = 0.0
	unit["moving"] = false
	unit["target_lon"] = float(unit.get("lon", 0.0))
	unit["target_lat"] = float(unit.get("lat", 0.0))
	unit["route_points"] = []
	_units[index] = unit
	return true


func set_current_governorate(unit_id: String, governorate_index: int) -> bool:
	if not _index_by_id.has(unit_id) or governorate_index < 0 or governorate_index >= 14:
		return false
	var index := int(_index_by_id[unit_id])
	var unit: Dictionary = _units[index]
	unit["current_governorate_index"] = governorate_index
	_units[index] = unit
	return true


func representative_id(governorate_index: int, unit_type: String) -> String:
	for unit in _units:
		if int(unit.get("home_governorate_index", -1)) != governorate_index:
			continue
		if str(unit.get("unit_type", "")) != unit_type:
			continue
		if bool(unit.get("alive", true)):
			return str(unit.get("id", ""))
	return ""


func validate() -> String:
	if not _seeded:
		return "heavy roster is not seeded"
	if _units.size() != 1400 or _index_by_id.size() != 1400:
		return "heavy roster total is not 1400"
	if count_type("tank") != 700:
		return "tank roster total is not 700"
	if count_type("rocket_launcher") != 280:
		return "rocket launcher roster total is not 280"
	if count_type("artillery") != 420:
		return "artillery roster total is not 420"
	for governorate_index in range(14):
		if count_governorate(governorate_index) != 100:
			return "governorate %d does not contain 100 heavy units" % governorate_index
	for unit in _units:
		var unit_id := str(unit.get("id", ""))
		if unit_id.is_empty() or not _index_by_id.has(unit_id):
			return "heavy roster contains invalid unit id"
		if float(unit.get("max_hp", 0.0)) <= 0.0:
			return "heavy roster contains invalid hit points"
	return ""


func get_governorate_units(governorate_index: int, alive_only: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if governorate_index < 0 or governorate_index >= 14:
		return result
	for unit in _units:
		if int(unit.get("current_governorate_index", -1)) != governorate_index:
			continue
		if alive_only and not bool(unit.get("alive", true)):
			continue
		result.append(unit.duplicate(true))
	return result


func set_surviving_hp(unit_id: String, hp: float) -> bool:
	if not _index_by_id.has(unit_id):
		return false
	var index := int(_index_by_id[unit_id])
	var unit: Dictionary = _units[index]
	if not bool(unit.get("alive", true)):
		return false
	var max_hp := maxf(1.0, float(unit.get("max_hp", 1.0)))
	var next_hp := clampf(hp, 0.0, max_hp)
	if next_hp <= 0.0:
		return false
	unit["hp"] = next_hp
	_units[index] = unit
	return true


func tick_movement(delta: float, excluded_ids: Dictionary = {}) -> int:
	if delta <= 0.0:
		return 0
	var moved_count: int = 0
	for i in range(_units.size()):
		var unit: Dictionary = _units[i]
		var unit_id: String = str(unit.get("id", ""))
		if excluded_ids.has(unit_id):
			continue
		if not bool(unit.get("alive", true)) or not bool(unit.get("moving", false)):
			continue

		var lon: float = float(unit.get("lon", 0.0))
		var lat: float = float(unit.get("lat", 0.0))
		var target_lon: float = float(unit.get("target_lon", lon))
		var target_lat: float = float(unit.get("target_lat", lat))
		var lat_scale_km: float = 111.32
		var lon_scale_km: float = maxf(1.0, 111.32 * cos(deg_to_rad(lat)))
		var delta_lon_km: float = (target_lon - lon) * lon_scale_km
		var delta_lat_km: float = (target_lat - lat) * lat_scale_km
		var distance_km: float = sqrt(delta_lon_km * delta_lon_km + delta_lat_km * delta_lat_km)
		if distance_km > 0.000001:
			unit["heading_rad"] = atan2(-delta_lon_km, delta_lat_km)
		var speed_km_sec: float = maxf(0.0, float(unit.get("speed_km_sec", 0.0)))
		var step_km: float = speed_km_sec * delta

		if distance_km <= maxf(0.0001, step_km):
			unit["lon"] = target_lon
			unit["lat"] = target_lat
			var pending: Array = unit.get("route_points", [])
			if not pending.is_empty():
				var next_point: Dictionary = pending.pop_front()
				unit["target_lon"] = float(next_point.get("lon", target_lon))
				unit["target_lat"] = float(next_point.get("lat", target_lat))
				unit["route_points"] = pending
				unit["moving"] = true
			else:
				unit["moving"] = false
		else:
			var ratio: float = step_km / distance_km
			unit["lon"] = lerpf(lon, target_lon, ratio)
			unit["lat"] = lerpf(lat, target_lat, ratio)

		_units[i] = unit
		moved_count += 1

	return moved_count


func set_heading(unit_id: String, heading_rad: float) -> bool:
	if not _index_by_id.has(unit_id):
		return false
	var index := int(_index_by_id[unit_id])
	var unit: Dictionary = _units[index]
	if not bool(unit.get("alive", true)):
		return false
	unit["heading_rad"] = wrapf(heading_rad, -PI, PI)
	_units[index] = unit
	return true
