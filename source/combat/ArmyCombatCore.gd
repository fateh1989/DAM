class_name ArmyCombatCore
extends RefCounted

const DEFAULT_UNIT_CATALOG := "res://source/combat/data/units.json"
const DEFAULT_WEAPON_CATALOG := "res://source/combat/data/weapons.json"

var unit_specs: Dictionary = {}
var weapon_specs: Dictionary = {}
var countries: Dictionary = {}


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func load_catalogs(
	unit_path: String = DEFAULT_UNIT_CATALOG,
	weapon_path: String = DEFAULT_WEAPON_CATALOG
) -> bool:
	var units: Dictionary = _load_json_dictionary(unit_path)
	var weapons: Dictionary = _load_json_dictionary(weapon_path)
	if units.is_empty() or weapons.is_empty():
		return false
	unit_specs = units
	weapon_specs = weapons
	return true


func create_country(
	country_id: String,
	display_name: String,
	treasury: int,
	initial_inventory: Dictionary
) -> bool:
	if country_id.is_empty() or countries.has(country_id):
		return false

	var inventory: Dictionary = {}
	var deployed: Dictionary = {}
	var destroyed: Dictionary = {}
	var purchased: Dictionary = {}

	for unit_type in unit_specs.keys():
		var key: String = str(unit_type)
		inventory[key] = maxi(0, int(initial_inventory.get(key, 0)))
		deployed[key] = 0
		destroyed[key] = 0
		purchased[key] = 0

	countries[country_id] = {
		"id": country_id,
		"name": display_name,
		"treasury": maxi(0, treasury),
		"inventory": inventory,
		"deployed": deployed,
		"destroyed": destroyed,
		"purchased": purchased,
		"total_spent": 0,
	}
	return true


func has_country(country_id: String) -> bool:
	return countries.has(country_id)


func get_country_snapshot(country_id: String) -> Dictionary:
	if not countries.has(country_id):
		return {}
	return (countries[country_id] as Dictionary).duplicate(true)


func unit_spec(unit_type: String) -> Dictionary:
	if not unit_specs.has(unit_type):
		return {}
	return (unit_specs[unit_type] as Dictionary).duplicate(true)


func weapon_spec(weapon_id: String) -> Dictionary:
	if not weapon_specs.has(weapon_id):
		return {}
	return (weapon_specs[weapon_id] as Dictionary).duplicate(true)


func purchase(country_id: String, unit_type: String, quantity: int = 1) -> Dictionary:
	if not countries.has(country_id):
		return {"ok": false, "reason": "unknown_country"}
	if not unit_specs.has(unit_type):
		return {"ok": false, "reason": "unknown_unit"}
	quantity = maxi(1, quantity)

	var spec: Dictionary = unit_specs[unit_type]
	var unit_cost: int = maxi(0, int(spec.get("cost", 0)))
	var total_cost: int = unit_cost * quantity
	var country: Dictionary = countries[country_id]
	var treasury: int = int(country.get("treasury", 0))
	if treasury < total_cost:
		return {
			"ok": false,
			"reason": "insufficient_funds",
			"required": total_cost,
			"treasury": treasury,
		}

	var inventory: Dictionary = country["inventory"]
	var purchased: Dictionary = country["purchased"]
	inventory[unit_type] = int(inventory.get(unit_type, 0)) + quantity
	purchased[unit_type] = int(purchased.get(unit_type, 0)) + quantity
	country["treasury"] = treasury - total_cost
	country["total_spent"] = int(country.get("total_spent", 0)) + total_cost
	country["inventory"] = inventory
	country["purchased"] = purchased
	countries[country_id] = country

	return {
		"ok": true,
		"country_id": country_id,
		"unit_type": unit_type,
		"quantity": quantity,
		"cost": total_cost,
		"treasury": int(country["treasury"]),
	}


func deploy(country_id: String, unit_type: String, quantity: int = 1) -> Dictionary:
	if not countries.has(country_id):
		return {"ok": false, "reason": "unknown_country"}
	if not unit_specs.has(unit_type):
		return {"ok": false, "reason": "unknown_unit"}
	quantity = maxi(1, quantity)

	var country: Dictionary = countries[country_id]
	var inventory: Dictionary = country["inventory"]
	var deployed: Dictionary = country["deployed"]
	var available: int = int(inventory.get(unit_type, 0))
	if available < quantity:
		return {
			"ok": false,
			"reason": "insufficient_inventory",
			"available": available,
		}

	inventory[unit_type] = available - quantity
	deployed[unit_type] = int(deployed.get(unit_type, 0)) + quantity
	country["inventory"] = inventory
	country["deployed"] = deployed
	countries[country_id] = country
	return {"ok": true, "quantity": quantity}


func return_to_inventory(country_id: String, unit_type: String, quantity: int = 1) -> Dictionary:
	if not countries.has(country_id):
		return {"ok": false, "reason": "unknown_country"}
	quantity = maxi(1, quantity)

	var country: Dictionary = countries[country_id]
	var inventory: Dictionary = country["inventory"]
	var deployed: Dictionary = country["deployed"]
	var active: int = int(deployed.get(unit_type, 0))
	if active < quantity:
		return {"ok": false, "reason": "insufficient_deployed", "available": active}

	deployed[unit_type] = active - quantity
	inventory[unit_type] = int(inventory.get(unit_type, 0)) + quantity
	country["inventory"] = inventory
	country["deployed"] = deployed
	countries[country_id] = country
	return {"ok": true, "quantity": quantity}


func record_loss(country_id: String, unit_type: String, quantity: int = 1) -> Dictionary:
	if not countries.has(country_id):
		return {"ok": false, "reason": "unknown_country"}
	quantity = maxi(1, quantity)

	var country: Dictionary = countries[country_id]
	var deployed: Dictionary = country["deployed"]
	var destroyed: Dictionary = country["destroyed"]
	var active: int = int(deployed.get(unit_type, 0))
	var applied: int = mini(active, quantity)
	if applied <= 0:
		return {"ok": false, "reason": "nothing_deployed"}

	deployed[unit_type] = active - applied
	destroyed[unit_type] = int(destroyed.get(unit_type, 0)) + applied
	country["deployed"] = deployed
	country["destroyed"] = destroyed
	countries[country_id] = country
	return {"ok": true, "quantity": applied}


func create_unit_state(unit_type: String, country_id: String) -> Dictionary:
	if not unit_specs.has(unit_type):
		return {}
	var spec: Dictionary = unit_specs[unit_type]
	var max_hp: float = maxf(1.0, float(spec.get("hp", 100.0)))
	return {
		"country_id": country_id,
		"unit_type": unit_type,
		"domain": str(spec.get("domain", "ground")),
		"hp": max_hp,
		"max_hp": max_hp,
		"armor": clampf(float(spec.get("armor", 0.0)), 0.0, 0.90),
		"weapons": (spec.get("weapons", []) as Array).duplicate(),
		"speed_km_sec": maxf(0.0, float(spec.get("speed_km_sec", 0.0))),
		"alive": true,
	}


func weapon_can_target(weapon_id: String, target_domain: String) -> bool:
	if not weapon_specs.has(weapon_id):
		return false
	var targets: Array = weapon_specs[weapon_id].get("targets", [])
	return target_domain in targets or "both" in targets


func apply_damage(
	unit_state: Dictionary,
	raw_damage: float,
	armor_penetration: float = 0.0
) -> Dictionary:
	var state: Dictionary = unit_state.duplicate(true)
	if not bool(state.get("alive", true)):
		return {"state": state, "damage": 0.0, "destroyed": true}

	var armor: float = clampf(float(state.get("armor", 0.0)), 0.0, 0.90)
	var penetration: float = clampf(armor_penetration, 0.0, 0.90)
	var effective_armor: float = maxf(0.0, armor - penetration)
	var damage: float = maxf(0.0, raw_damage) * (1.0 - effective_armor)
	state["hp"] = maxf(0.0, float(state.get("hp", 0.0)) - damage)
	var destroyed_now: bool = float(state["hp"]) <= 0.0
	state["alive"] = not destroyed_now
	return {"state": state, "damage": damage, "destroyed": destroyed_now}


func resolve_shot(
	attacker_state: Dictionary,
	target_state: Dictionary,
	weapon_id: String
) -> Dictionary:
	if not bool(attacker_state.get("alive", false)):
		return {"ok": false, "reason": "attacker_destroyed"}
	if not bool(target_state.get("alive", false)):
		return {"ok": false, "reason": "target_destroyed"}
	if not weapon_specs.has(weapon_id):
		return {"ok": false, "reason": "unknown_weapon"}

	var attacker_weapons: Array = attacker_state.get("weapons", [])
	if not weapon_id in attacker_weapons:
		return {"ok": false, "reason": "weapon_not_mounted"}

	var target_domain: String = str(target_state.get("domain", "ground"))
	if not weapon_can_target(weapon_id, target_domain):
		return {"ok": false, "reason": "invalid_target_domain"}

	var weapon: Dictionary = weapon_specs[weapon_id]
	var hit: Dictionary = apply_damage(
		target_state,
		float(weapon.get("damage", 0.0)),
		float(weapon.get("armor_penetration", 0.0))
	)
	return {
		"ok": true,
		"weapon_id": weapon_id,
		"damage": float(hit.get("damage", 0.0)),
		"destroyed": bool(hit.get("destroyed", false)),
		"target": hit.get("state", {}),
		"range_km": float(weapon.get("range_km", 0.0)),
		"cooldown_s": float(weapon.get("cooldown_s", 0.0)),
		"projectile": str(weapon.get("projectile", "direct")),
		"fire_sound": str(weapon.get("fire_sound", "")),
		"impact_effect": str(weapon.get("impact_effect", "")),
	}
