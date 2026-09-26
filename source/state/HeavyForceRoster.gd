class_name HeavyForceRoster
extends RefCounted

const FORCE_TEMPLATE := {
	"tank": 50,
	"rocket_launcher": 20,
	"artillery": 30,
}
const UNIT_ORDER := ["tank", "rocket_launcher", "artillery"]

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
					"alive": true,
					"hp": max_hp,
					"max_hp": max_hp,
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
	if not _index_by_id.has(unit_id):
		return false
	var index := int(_index_by_id[unit_id])
	var unit: Dictionary = _units[index]
	if not bool(unit.get("alive", true)):
		return false
	unit["target_lon"] = target_lon
	unit["target_lat"] = target_lat
	unit["moving"] = true
	_units[index] = unit
	return true


func stop_unit(unit_id: String) -> bool:
	if not _index_by_id.has(unit_id):
		return false
	var index := int(_index_by_id[unit_id])
	var unit: Dictionary = _units[index]
	unit["target_lon"] = float(unit.get("lon", 0.0))
	unit["target_lat"] = float(unit.get("lat", 0.0))
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
