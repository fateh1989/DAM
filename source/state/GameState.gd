extends Node

signal province_selected(province_id: String)
signal battle_started(province_id: String)
signal battle_finished(province_id: String, result: Dictionary)

const ArmyCombatCoreScript = preload("res://source/combat/ArmyCombatCore.gd")
const EconomyCoreScript = preload("res://source/economy/EconomyCore.gd")

var army_core = null
var economy_core = null
var selected_province_id := "aleppo"
var selected_province_name := "حلب"
var active_battle: Dictionary = {}
var _started := false


func _ready() -> void:
	ensure_started()


func ensure_started() -> bool:
	if _started and army_core != null:
		return true

	army_core = ArmyCombatCoreScript.new()
	if not army_core.load_catalogs():
		army_core = null
		_started = false
		return false

	if not army_core.has_country("syria"):
		army_core.create_country(
			"syria",
			"سوريا",
			50000,
			{
				"tank": 14,
				"infantry_squad": 24,
				"artillery": 6,
				"air_defense": 6,
				"helicopter": 4,
				"fighter": 4,
			}
		)

	if economy_core == null:
		economy_core = EconomyCoreScript.new()
		economy_core.seed_syria_gameplay_baseline()

	_started = true
	return true


func select_province(province_id: String, display_name: String) -> void:
	selected_province_id = province_id
	selected_province_name = display_name
	province_selected.emit(province_id)


func begin_battle(province_id: String, display_name: String) -> bool:
	if not ensure_started():
		return false
	select_province(province_id, display_name)
	active_battle = {
		"province_id": province_id,
		"province_name": display_name,
		"country_id": "syria",
		"started_at_msec": Time.get_ticks_msec(),
		"force": {
			"tank": 6,
			"infantry_squad": 4,
		},
	}
	battle_started.emit(province_id)
	return true


func finish_battle(result: Dictionary = {}) -> void:
	if active_battle.is_empty():
		return
	var province_id := str(active_battle.get("province_id", selected_province_id))
	active_battle["result"] = result.duplicate(true)
	battle_finished.emit(province_id, result)
	active_battle = {}


func get_country_snapshot(country_id: String = "syria") -> Dictionary:
	if not ensure_started():
		return {}
	return army_core.get_country_snapshot(country_id)


func tick_economy(hours: float) -> Dictionary:
	if not ensure_started() or economy_core == null:
		return {}
	return economy_core.tick(hours)


func get_economy_snapshot() -> Dictionary:
	if not ensure_started() or economy_core == null:
		return {}
	return economy_core.get_snapshot()


func damage_economy_area(governorate_id: String, severity: float, kind_filter: String = "") -> int:
	if not ensure_started() or economy_core == null:
		return 0
	return economy_core.apply_area_damage(governorate_id, severity, kind_filter)
