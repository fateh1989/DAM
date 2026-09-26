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
				var unit := {
					"id": unit_id,
					"home_governorate_index": governorate_index,
					"current_governorate_index": governorate_index,
					"unit_type": unit_type,
					"slot": slot,
					"lon": base_lon,
					"lat": base_lat,
					"target_lon": base_lon,
					"target_lat": base_lat,
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
