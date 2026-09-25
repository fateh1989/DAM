extends RefCounted

# Gameplay economy model. Values are design baselines, not a claim about real-world output.
const STATE_HEALTHY := "healthy"
const STATE_DAMAGED := "damaged"
const STATE_DISABLED := "disabled"
const STATE_RECOVERING := "recovering"

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
	}
	return true


func has_node(node_id: String) -> bool:
	return nodes.has(node_id)


func get_node_snapshot(node_id: String) -> Dictionary:
	if not nodes.has(node_id):
		return {}
	return (nodes[node_id] as Dictionary).duplicate(true)
