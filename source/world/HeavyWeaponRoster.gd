extends RefCounted

const TANKS_PER_PROVINCE := 50
const LAUNCHERS_PER_PROVINCE := 20
const ARTILLERY_PER_PROVINCE := 30
const HEAVY_WEAPONS_PER_PROVINCE := TANKS_PER_PROVINCE + LAUNCHERS_PER_PROVINCE + ARTILLERY_PER_PROVINCE

var _province_count := 0
var _inventories: Array[Dictionary] = []


func setup(province_count: int) -> void:
	_province_count = maxi(0, province_count)
	_inventories.clear()
	for i in range(_province_count):
		_inventories.append({
			"tank": TANKS_PER_PROVINCE,
			"launcher": LAUNCHERS_PER_PROVINCE,
			"artillery": ARTILLERY_PER_PROVINCE,
		})


func province_count() -> int:
	return _province_count


func get_inventory(index: int) -> Dictionary:
	if index < 0 or index >= _inventories.size():
		return {}
	return _inventories[index].duplicate(true)


func get_count(index: int, weapon_type: String) -> int:
	if index < 0 or index >= _inventories.size():
		return -1
	if weapon_type not in ["tank", "launcher", "artillery"]:
		return -1
	return int(_inventories[index].get(weapon_type, 0))


func get_province_total(index: int) -> int:
	var inventory := get_inventory(index)
	if inventory.is_empty():
		return -1
	return int(inventory["tank"]) + int(inventory["launcher"]) + int(inventory["artillery"])


func get_total_by_type(weapon_type: String) -> int:
	if weapon_type not in ["tank", "launcher", "artillery"]:
		return -1
	var total := 0
	for inventory in _inventories:
		total += int(inventory.get(weapon_type, 0))
	return total


func get_grand_total() -> int:
	var total := 0
	for i in range(_inventories.size()):
		total += get_province_total(i)
	return total


func apply_loss(index: int, weapon_type: String, quantity: int = 1) -> int:
	if index < 0 or index >= _inventories.size():
		return -1
	if weapon_type not in ["tank", "launcher", "artillery"]:
		return -1
	var inventory: Dictionary = _inventories[index]
	inventory[weapon_type] = maxi(0, int(inventory.get(weapon_type, 0)) - maxi(0, quantity))
	_inventories[index] = inventory
	return int(inventory[weapon_type])


func restore(index: int, weapon_type: String, quantity: int = 1) -> int:
	if index < 0 or index >= _inventories.size():
		return -1
	if weapon_type not in ["tank", "launcher", "artillery"]:
		return -1
	var inventory: Dictionary = _inventories[index]
	inventory[weapon_type] = int(inventory.get(weapon_type, 0)) + maxi(0, quantity)
	_inventories[index] = inventory
	return int(inventory[weapon_type])
