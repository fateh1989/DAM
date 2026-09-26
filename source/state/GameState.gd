extends Node

signal province_selected(province_id: String)
signal battle_started(province_id: String)
signal battle_finished(province_id: String, result: Dictionary)

const ArmyCombatCoreScript = preload("res://source/combat/ArmyCombatCore.gd")
const EconomyCoreScript = preload("res://source/economy/EconomyCore.gd")
const HeavyForceRosterScript = preload("res://source/state/HeavyForceRoster.gd")

var army_core = null
var economy_core = null
var heavy_force_roster = null
var _heavy_roster_deployed := false
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
				"tank": 700,
				"rocket_launcher": 280,
				"artillery": 420,
				"infantry_squad": 24,
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


func ensure_heavy_force_roster(governorates: Array) -> bool:
	if not ensure_started():
		return false
	if heavy_force_roster == null:
		heavy_force_roster = HeavyForceRosterScript.new()
	var specs := {}
	for unit_type in ["tank", "rocket_launcher", "artillery"]:
		specs[unit_type] = army_core.unit_spec(unit_type)
	if not heavy_force_roster.seed(governorates, specs):
		return false
	if not str(heavy_force_roster.validate()).is_empty():
		return false
	return _ensure_heavy_roster_deployed()


func _ensure_heavy_roster_deployed() -> bool:
	if _heavy_roster_deployed:
		return true
	if army_core == null or heavy_force_roster == null or not heavy_force_roster.is_seeded():
		return false
	var desired := {"tank": 700, "rocket_launcher": 280, "artillery": 420}
	var snapshot: Dictionary = army_core.get_country_snapshot("syria")
	var deployed: Dictionary = snapshot.get("deployed", {})
	var inventory: Dictionary = snapshot.get("inventory", {})

	var complete := true
	for unit_type in desired.keys():
		if int(deployed.get(unit_type, 0)) != int(desired[unit_type]):
			complete = false
			break
	if complete:
		_heavy_roster_deployed = true
		return true

	for unit_type in desired.keys():
		var needed := int(desired[unit_type]) - int(deployed.get(unit_type, 0))
		if needed < 0 or int(inventory.get(unit_type, 0)) < needed:
			return false

	for unit_type in desired.keys():
		var needed := int(desired[unit_type]) - int(deployed.get(unit_type, 0))
		if needed <= 0:
			continue
		var result: Dictionary = army_core.deploy("syria", str(unit_type), needed)
		if not bool(result.get("ok", false)):
			return false

	_heavy_roster_deployed = true
	return true


func get_heavy_representative_id(governorate_index: int, unit_type: String) -> String:
	if heavy_force_roster == null:
		return ""
	return heavy_force_roster.representative_id(governorate_index, unit_type)
