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
