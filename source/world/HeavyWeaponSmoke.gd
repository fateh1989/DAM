extends RefCounted

const ROSTER_SCRIPT := preload("res://source/world/HeavyWeaponRoster.gd")
const VISUAL_SCRIPT := preload("res://source/world/HeavyWeaponVisual.gd")

func run(scene: Node) -> String:
	var roster = ROSTER_SCRIPT.new()
	roster.setup(14)
	if roster.province_count() != 14:
		return "heavy weapon roster does not cover fourteen governorates"
	for i in range(14):
		if roster.get_count(i, "tank") != 50:
			return "governorate tank count is not fifty"
		if roster.get_count(i, "launcher") != 20:
			return "governorate launcher count is not twenty"
		if roster.get_count(i, "artillery") != 30:
			return "governorate artillery count is not thirty"
		if roster.get_province_total(i) != 100:
			return "governorate heavy weapon total is not one hundred"
	if roster.get_total_by_type("tank") != 700:
		return "country tank total is not seven hundred"
	if roster.get_total_by_type("launcher") != 280:
		return "country launcher total is not two hundred eighty"
	if roster.get_total_by_type("artillery") != 420:
		return "country artillery total is not four hundred twenty"
	if roster.get_grand_total() != 1400:
		return "country heavy weapon total is not fourteen hundred"
	var live_markers: Array = scene.call("get_heavy_weapon_markers")
	if live_markers.size() != 42:
		return "strategic world does not expose three heavy weapon groups per governorate"
	if int(scene.call("get_heavy_weapon_country_total")) != 1400:
		return "strategic world heavy weapon total is not fourteen hundred"
	for province_index in range(14):
		var inventory: Dictionary = scene.call("get_heavy_weapon_inventory", province_index)
		if int(inventory.get("tank", -1)) != 50 or int(inventory.get("launcher", -1)) != 20 or int(inventory.get("artillery", -1)) != 30:
			return "live governorate arsenal does not match requested 50 20 30 inventory"
	var remaining_tanks := int(scene.call("apply_heavy_weapon_loss", 2, "tank", 3))
	if remaining_tanks != 47 or int(scene.call("get_heavy_weapon_country_total")) != 1397:
		return "heavy weapon losses do not reduce persistent governorate inventory"
	var aleppo_tank_marker: Node3D = null
	for marker in live_markers:
		if int(marker.get("province_index")) == 2 and str(marker.get("weapon_type")) == "tank":
			aleppo_tank_marker = marker
			break
	if aleppo_tank_marker == null or str(aleppo_tank_marker.call("get_count_label_text")) != "×47":
		return "visible arsenal count did not follow persistent tank losses"
	if int(scene.call("restore_heavy_weapon", 2, "tank", 3)) != 50:
		return "heavy weapon inventory could not be restored after loss test"
	if int(scene.call("get_heavy_weapon_country_total")) != 1400:
		return "heavy weapon total did not return to fourteen hundred after restore"

	var west_tank := VISUAL_SCRIPT.new()
	west_tank.setup("tank", "west", 0, 50)
	var east_tank := VISUAL_SCRIPT.new()
	east_tank.setup("tank", "east", 0, 50)
	var west_sig: Dictionary = west_tank.call("get_visual_signature")
	var east_sig: Dictionary = east_tank.call("get_visual_signature")
	if west_sig.get("hull_size", Vector3.ZERO) == east_sig.get("hull_size", Vector3.ZERO):
		west_tank.free()
		east_tank.free()
		return "west and east tanks do not have different hull proportions"
	west_tank.free()
	east_tank.free()

	for family_name in ["west", "east"]:
		var tank := VISUAL_SCRIPT.new()
		tank.setup("tank", family_name, 0, 50)
		if tank.get_part("TurretPivot") == null or tank.get_part("Barrel") == null:
			tank.free()
			return "tank visual lacks independent turret and barrel structure"
		if tank.get_part("Track_L") == null or tank.get_part("Track_R") == null:
			tank.free()
			return "tank visual lacks left and right tracks"
		if not bool(tank.call("set_aim_yaw", 73.0)):
			tank.free()
			return "tank turret yaw control is unavailable"
		if not bool(tank.call("set_weapon_elevation", 14.0)) or absf(float(tank.call("get_weapon_elevation")) - 14.0) > 0.01:
			tank.free()
			return "tank gun elevation joint is unavailable"
		if absf(float(tank.call("get_aim_yaw")) - 73.0) > 0.01:
			tank.free()
			return "tank turret does not rotate independently"
		var tank_barrel := tank.get_part("Barrel") as Node3D
		var tank_barrel_rest := tank_barrel.position
		if not bool(tank.call("apply_fire_recoil_visual")) or tank_barrel.position == tank_barrel_rest:
			tank.free()
			return "tank cannon lacks visible recoil"
		tank.call("reset_fire_recoil_visual")
		if tank_barrel.position != tank_barrel_rest or bool(tank.call("is_recoil_active")):
			tank.free()
			return "tank cannon recoil does not reset"
		tank.free()

		var launcher := VISUAL_SCRIPT.new()
		launcher.setup("launcher", family_name, 0, 20)
		if launcher.get_part("LauncherPivot") == null or launcher.get_part("RocketPod_00") == null:
			launcher.free()
			return "launcher visual lacks rotating launcher structure"
		var expected_pods := 2 if family_name == "west" else 3
		if int(launcher.call("get_launcher_pod_count")) != expected_pods:
			launcher.free()
			return "launcher family pod layout is incorrect"
		if not bool(launcher.call("set_aim_yaw", -61.0)) or absf(float(launcher.call("get_aim_yaw")) + 61.0) > 0.01:
			launcher.free()
			return "launcher does not rotate independently from chassis"
		if not bool(launcher.call("set_weapon_elevation", 35.0)) or absf(float(launcher.call("get_weapon_elevation")) - 35.0) > 0.01:
			launcher.free()
			return "launcher elevation joint is unavailable"
		launcher.free()

		var artillery := VISUAL_SCRIPT.new()
		artillery.setup("artillery", family_name, 0, 30)
		if artillery.get_part("TurretPivot") == null or artillery.get_part("BarrelPivot") == null:
			artillery.free()
			return "artillery visual lacks turret and elevation pivot"
		if not bool(artillery.call("set_weapon_elevation", 42.0)) or absf(float(artillery.call("get_weapon_elevation")) - 42.0) > 0.01:
			artillery.free()
			return "artillery gun elevation joint is unavailable"
		var artillery_barrel := artillery.get_part("Barrel") as Node3D
		var artillery_rest := artillery_barrel.position
		if not bool(artillery.call("apply_fire_recoil_visual")) or artillery_barrel.position == artillery_rest:
			artillery.free()
			return "artillery cannon lacks visible recoil"
		artillery.call("reset_fire_recoil_visual")
		if artillery_barrel.position != artillery_rest:
			artillery.free()
			return "artillery recoil does not reset"
		if family_name == "west" and artillery.get_part("RearAmmoBox") == null:
			artillery.free()
			return "western artillery lacks rear ammunition housing"
		if family_name == "east" and artillery.get_part("CommanderCupola") == null:
			artillery.free()
			return "eastern artillery lacks compact cupola silhouette"
		artillery.free()

	return ""
