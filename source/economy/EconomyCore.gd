extends RefCounted

# Gameplay economy model. Values are design baselines, not a claim about real-world output.
const STATE_HEALTHY := "healthy"
const STATE_DAMAGED := "damaged"
const STATE_DISABLED := "disabled"
const STATE_RECOVERING := "recovering"

const INDUSTRIAL_PROFILES := {
	"textile": {"power_need": 0.72, "water_need": 0.54, "value_multiplier": 0.92},
	"food": {"power_need": 0.58, "water_need": 0.82, "value_multiplier": 1.00},
	"chemical": {"power_need": 0.88, "water_need": 0.76, "value_multiplier": 1.24},
	"engineering": {"power_need": 0.82, "water_need": 0.46, "value_multiplier": 1.18},
	"energy": {"power_need": 0.38, "water_need": 0.44, "value_multiplier": 1.08},
}

const RESOURCE_CATALOG := {
	"sheep": {"base_output": 0.0, "unit_value": 85.0, "sale_ratio": 0.0},
	"grain": {"base_output": 18.0, "unit_value": 24.0, "sale_ratio": 0.72},
	"oil": {"base_output": 8.0, "unit_value": 72.0, "sale_ratio": 0.86},
	"gas": {"base_output": 9.0, "unit_value": 54.0, "sale_ratio": 0.82},
	"phosphate": {"base_output": 7.0, "unit_value": 38.0, "sale_ratio": 0.78},
	"industrial": {"base_output": 12.0, "unit_value": 46.0, "sale_ratio": 0.75},
	"market": {"base_output": 0.0, "unit_value": 0.0, "sale_ratio": 0.0},
	"electric": {"base_output": 0.0, "unit_value": 0.0, "sale_ratio": 0.0},
	"water": {"base_output": 0.0, "unit_value": 0.0, "sale_ratio": 0.0},
}

var nodes: Dictionary = {}
var treasury_income := 0.0
var elapsed_hours := 0.0


func has_resource_kind(kind: String) -> bool:
	return RESOURCE_CATALOG.has(kind)


func get_resource_catalog() -> Dictionary:
	return RESOURCE_CATALOG.duplicate(true)


func create_node(
	node_id: String,
	kind: String,
	governorate_id: String,
	capacity: float = 1.0
) -> bool:
	if node_id.is_empty() or nodes.has(node_id) or not has_resource_kind(kind):
		return false
	nodes[node_id] = {
		"id": node_id,
		"kind": kind,
		"governorate_id": governorate_id,
		"capacity": maxf(0.0, capacity),
		"state": STATE_HEALTHY,
		"damage_ratio": 0.0,
		"recovery_rate": 0.025,
		"logistics_ratio": 1.0,
		"route_security": 1.0,
		"power_ratio": 1.0,
		"water_ratio": 1.0,
		"stored_output": 0.0,
		"revenue_total": 0.0,
		"head_count": 0.0,
		"growth_rate": 0.0,
		"market_sale_rate": 0.0,
		"industrial_profile": "",
		"value_multiplier": 1.0,
	}
	return true


func has_node(node_id: String) -> bool:
	return nodes.has(node_id)


func get_node_snapshot(node_id: String) -> Dictionary:
	if not nodes.has(node_id):
		return {}
	return (nodes[node_id] as Dictionary).duplicate(true)


func _support_ratio(node: Dictionary) -> float:
	var logistics := clampf(float(node.get("logistics_ratio", 1.0)), 0.0, 1.0)
	var security := clampf(float(node.get("route_security", 1.0)), 0.0, 1.0)
	var power := clampf(float(node.get("power_ratio", 1.0)), 0.0, 1.0)
	var water := clampf(float(node.get("water_ratio", 1.0)), 0.0, 1.0)
	return logistics * security * (0.35 + 0.65 * power) * (0.50 + 0.50 * water)


func get_node_throughput(node_id: String) -> float:
	if not nodes.has(node_id):
		return 0.0
	var node: Dictionary = nodes[node_id]
	if str(node.get("state", STATE_HEALTHY)) == STATE_DISABLED:
		return 0.0
	var damage_factor := 1.0 - clampf(float(node.get("damage_ratio", 0.0)), 0.0, 1.0)
	return maxf(0.0, float(node.get("capacity", 0.0)) * damage_factor * _support_ratio(node))


func _auto_sell_node(node_id: String) -> float:
	var node: Dictionary = nodes[node_id]
	var kind := str(node.get("kind", ""))
	var catalog: Dictionary = RESOURCE_CATALOG.get(kind, {})
	var sale_ratio := clampf(float(catalog.get("sale_ratio", 0.0)), 0.0, 1.0)
	var amount := float(node.get("stored_output", 0.0)) * sale_ratio
	var income := amount * float(catalog.get("unit_value", 0.0)) * float(node.get("value_multiplier", 1.0))
	node["stored_output"] = float(node.get("stored_output", 0.0)) - amount
	node["revenue_total"] = float(node.get("revenue_total", 0.0)) + income
	nodes[node_id] = node
	return income


func _advance_recovery(node_id: String, hours: float) -> void:
	var node: Dictionary = nodes[node_id]
	var damage := clampf(float(node.get("damage_ratio", 0.0)), 0.0, 1.0)
	if damage <= 0.0:
		node["damage_ratio"] = 0.0
		node["state"] = STATE_HEALTHY
		nodes[node_id] = node
		return
	damage = maxf(0.0, damage - float(node.get("recovery_rate", 0.025)) * hours)
	node["damage_ratio"] = damage
	node["state"] = STATE_HEALTHY if damage <= 0.0 else STATE_RECOVERING
	nodes[node_id] = node


func _auto_sell_livestock(node_id: String, hours: float) -> float:
	var node: Dictionary = nodes[node_id]
	if str(node.get("kind", "")) != "sheep":
		return 0.0
	var head_count := maxf(0.0, float(node.get("head_count", 0.0)))
	var sale_rate := clampf(float(node.get("market_sale_rate", 0.0)), 0.0, 1.0)
	var sale_count := minf(head_count, head_count * sale_rate * hours / 24.0 * get_node_throughput(node_id))
	if sale_count <= 0.0:
		return 0.0
	var unit_value := float((RESOURCE_CATALOG["sheep"] as Dictionary).get("unit_value", 0.0))
	var income := sale_count * unit_value
	node["head_count"] = head_count - sale_count
	node["revenue_total"] = float(node.get("revenue_total", 0.0)) + income
	nodes[node_id] = node
	return income


func tick(hours: float) -> Dictionary:
	hours = maxf(0.0, hours)
	if hours <= 0.0:
		return {"hours": 0.0, "produced": 0.0, "income": 0.0}
	var produced_total := 0.0
	for node_id in nodes.keys():
		_advance_recovery(str(node_id), hours)
	for node_id in nodes.keys():
		var node: Dictionary = nodes[node_id]
		var kind := str(node.get("kind", ""))
		var catalog: Dictionary = RESOURCE_CATALOG.get(kind, {})
		if kind == "sheep":
			var head_count := float(node.get("head_count", 0.0))
			var growth_rate := maxf(0.0, float(node.get("growth_rate", 0.0)))
			node["head_count"] = head_count + head_count * growth_rate * hours / 24.0 * get_node_throughput(str(node_id))
			nodes[node_id] = node
		var production := float(catalog.get("base_output", 0.0)) * get_node_throughput(str(node_id)) * hours
		node["stored_output"] = float(node.get("stored_output", 0.0)) + production
		nodes[node_id] = node
		produced_total += production
	var income_total := 0.0
	for node_id in nodes.keys():
		income_total += _auto_sell_livestock(str(node_id), hours)
		income_total += _auto_sell_node(str(node_id))
	treasury_income += income_total
	elapsed_hours += hours
	return {"hours": hours, "produced": produced_total, "income": income_total}


func apply_damage(node_id: String, severity: float) -> bool:
	if not nodes.has(node_id):
		return false
	var node: Dictionary = nodes[node_id]
	var damage := clampf(float(node.get("damage_ratio", 0.0)) + maxf(0.0, severity), 0.0, 1.0)
	node["damage_ratio"] = damage
	node["state"] = STATE_DISABLED if damage >= 0.75 else STATE_DAMAGED
	nodes[node_id] = node
	return true


func set_logistics(node_id: String, logistics_ratio: float, route_security: float = 1.0) -> bool:
	if not nodes.has(node_id):
		return false
	var node: Dictionary = nodes[node_id]
	node["logistics_ratio"] = clampf(logistics_ratio, 0.0, 1.0)
	node["route_security"] = clampf(route_security, 0.0, 1.0)
	nodes[node_id] = node
	return true


func set_support(node_id: String, power_ratio: float, water_ratio: float) -> bool:
	if not nodes.has(node_id):
		return false
	var node: Dictionary = nodes[node_id]
	node["power_ratio"] = clampf(power_ratio, 0.0, 1.0)
	node["water_ratio"] = clampf(water_ratio, 0.0, 1.0)
	nodes[node_id] = node
	return true


func configure_livestock(node_id: String, head_count: float, daily_growth_rate: float) -> bool:
	if not nodes.has(node_id):
		return false
	var node: Dictionary = nodes[node_id]
	if str(node.get("kind", "")) != "sheep":
		return false
	node["head_count"] = maxf(0.0, head_count)
	node["growth_rate"] = maxf(0.0, daily_growth_rate)
	nodes[node_id] = node
	return true


func configure_livestock_market(node_id: String, daily_sale_rate: float) -> bool:
	if not nodes.has(node_id):
		return false
	var node: Dictionary = nodes[node_id]
	if str(node.get("kind", "")) != "sheep":
		return false
	node["market_sale_rate"] = clampf(daily_sale_rate, 0.0, 1.0)
	nodes[node_id] = node
	return true


func configure_industrial_profile(node_id: String, profile: String) -> bool:
	if not nodes.has(node_id) or not INDUSTRIAL_PROFILES.has(profile):
		return false
	var node: Dictionary = nodes[node_id]
	if str(node.get("kind", "")) != "industrial":
		return false
	var data: Dictionary = INDUSTRIAL_PROFILES[profile]
	node["industrial_profile"] = profile
	node["value_multiplier"] = float(data.get("value_multiplier", 1.0))
	nodes[node_id] = node
	return true


func reset() -> void:
	nodes.clear()
	treasury_income = 0.0
	elapsed_hours = 0.0


func seed_syria_gameplay_baseline() -> void:
	reset()
	create_node("aleppo_industry", "industrial", "aleppo", 1.20)
	configure_industrial_profile("aleppo_industry", "engineering")
	create_node("aleppo_market", "market", "aleppo", 1.00)
	create_node("aleppo_sheep", "sheep", "aleppo", 0.90)
	configure_livestock("aleppo_sheep", 920.0, 0.004)
	configure_livestock_market("aleppo_sheep", 0.006)

	create_node("hama_grain", "grain", "hama", 1.15)
	create_node("hama_sheep", "sheep", "hama", 0.95)
	configure_livestock("hama_sheep", 760.0, 0.004)
	configure_livestock_market("hama_sheep", 0.006)

	create_node("homs_industry", "industrial", "homs", 1.00)
	configure_industrial_profile("homs_industry", "chemical")
	create_node("homs_phosphate", "phosphate", "homs", 0.90)

	create_node("deir_oil", "oil", "deir_ez_zor", 1.10)
	create_node("deir_gas", "gas", "deir_ez_zor", 1.00)
	create_node("deir_market", "market", "deir_ez_zor", 0.80)

	create_node("hasakah_grain", "grain", "hasakah", 1.20)
	create_node("hasakah_sheep", "sheep", "hasakah", 1.00)
	configure_livestock("hasakah_sheep", 1100.0, 0.004)
	configure_livestock_market("hasakah_sheep", 0.006)

	create_node("damascus_industry", "industrial", "damascus", 1.15)
	configure_industrial_profile("damascus_industry", "textile")
	create_node("damascus_market", "market", "damascus", 1.20)
	create_node("damascus_power", "electric", "damascus", 1.00)
	create_node("damascus_water", "water", "damascus", 1.00)

	create_node("latakia_market", "market", "latakia", 0.90)
	create_node("daraa_grain", "grain", "daraa", 0.85)
	create_node("raqqa_grain", "grain", "raqqa", 1.05)


func get_governorate_snapshot(governorate_id: String) -> Dictionary:
	var result := {
		"governorate_id": governorate_id,
		"node_count": 0,
		"capacity": 0.0,
		"throughput": 0.0,
		"revenue_total": 0.0,
		"livestock": 0.0,
		"nodes": [],
	}
	for node_id in nodes.keys():
		var node: Dictionary = nodes[node_id]
		if str(node.get("governorate_id", "")) != governorate_id:
			continue
		result["node_count"] = int(result["node_count"]) + 1
		result["capacity"] = float(result["capacity"]) + float(node.get("capacity", 0.0))
		result["throughput"] = float(result["throughput"]) + get_node_throughput(str(node_id))
		result["revenue_total"] = float(result["revenue_total"]) + float(node.get("revenue_total", 0.0))
		result["livestock"] = float(result["livestock"]) + float(node.get("head_count", 0.0))
		(result["nodes"] as Array).append(node.duplicate(true))
	return result


func apply_area_damage(governorate_id: String, severity: float, kind_filter: String = "") -> int:
	var affected := 0
	for node_id in nodes.keys():
		var node: Dictionary = nodes[node_id]
		if str(node.get("governorate_id", "")) != governorate_id:
			continue
		if not kind_filter.is_empty() and str(node.get("kind", "")) != kind_filter:
			continue
		if apply_damage(str(node_id), severity):
			affected += 1
	return affected
