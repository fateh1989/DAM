extends SceneTree

const EconomyCoreScript = preload("res://source/economy/EconomyCore.gd")


func _initialize() -> void:
	call_deferred("_run")


func _fail(code: int, message: String) -> void:
	push_error(message)
	quit(code)


func _run() -> void:
	var economy = EconomyCoreScript.new()
	economy.seed_syria_gameplay_baseline()

	var initial: Dictionary = economy.get_snapshot()
	if int(initial.get("node_count", 0)) < 15:
		_fail(2, "Economy smoke: gameplay baseline did not seed enough nodes")
		return

	var income_before := float(initial.get("treasury_income", 0.0))
	var day: Dictionary = economy.tick(24.0)
	if float(day.get("income", 0.0)) <= 0.0:
		_fail(3, "Economy smoke: automatic daily income did not run")
		return
	if float(economy.get_snapshot().get("treasury_income", 0.0)) <= income_before:
		_fail(4, "Economy smoke: treasury income did not accumulate")
		return

	var oil_before := economy.get_node_throughput("deir_oil")
	if oil_before <= 0.0:
		_fail(5, "Economy smoke: oil node started without throughput")
		return
	economy.apply_damage("deir_oil", 0.55)
	var oil_damaged := economy.get_node_throughput("deir_oil")
	if oil_damaged <= 0.0 or oil_damaged >= oil_before:
		_fail(6, "Economy smoke: damage did not reduce oil throughput")
		return

	economy.apply_damage("deir_oil", 0.45)
	if economy.get_node_throughput("deir_oil") != 0.0:
		_fail(7, "Economy smoke: disabled node still produced")
		return
	economy.tick(12.0)
	if not economy.has_node("deir_oil"):
		_fail(8, "Economy smoke: attacked resource disappeared permanently")
		return
	if economy.get_node_throughput("deir_oil") <= 0.0:
		_fail(9, "Economy smoke: disabled resource did not enter recovery")
		return

	var grain_before := economy.get_node_throughput("hama_grain")
	economy.set_logistics("hama_grain", 0.50, 0.50)
	if economy.get_node_throughput("hama_grain") >= grain_before:
		_fail(10, "Economy smoke: unsafe logistics did not reduce throughput")
		return

	var aleppo_affected := economy.apply_area_damage("aleppo", 0.20)
	if aleppo_affected < 2:
		_fail(11, "Economy smoke: area damage did not affect Aleppo economy")
		return
	var aleppo: Dictionary = economy.get_governorate_snapshot("aleppo")
	if int(aleppo.get("node_count", 0)) < 2:
		_fail(12, "Economy smoke: governorate snapshot missing nodes")
		return

	var node_count_before := int(economy.get_snapshot().get("node_count", 0))
	for _day in range(30):
		economy.tick(24.0)
	var month: Dictionary = economy.get_snapshot()
	if int(month.get("node_count", 0)) != node_count_before:
		_fail(13, "Economy smoke: long recovery simulation removed persistent nodes")
		return
	if int((month.get("state_counts", {}) as Dictionary).get("disabled", 0)) > 0:
		_fail(14, "Economy smoke: recoverable nodes stayed permanently disabled")
		return

	print("CHECKPOINT economy-foundation-01 PASSED")
	print("Economy smoke: automatic production + income + damage + recovery + logistics OK")
	quit(0)
