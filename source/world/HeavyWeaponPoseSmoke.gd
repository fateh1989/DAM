extends RefCounted

func run(scene: Node) -> String:
	var samples := {}
	for raw_unit in scene._units:
		var unit: Dictionary = raw_unit
		var unit_type := str(unit.get("unit_type", ""))
		if samples.has(unit_type):
			continue
		var node = unit.get("node")
		if node is Node3D and is_instance_valid(node):
			samples[unit_type] = node

	for required in ["tank", "artillery", "rocket_launcher"]:
		if not samples.has(required):
			return "missing visual sample for " + required

	var tank: Node3D = samples["tank"]
	if not bool(scene.call("set_heavy_visual_weapon_pose", tank, 37.0, 12.0)):
		return "tank weapon pose rejected"
	var tank_turret := tank.get_node_or_null("TankModel/TurretPivot") as Node3D
	var tank_gun := tank.get_node_or_null("TankModel/TurretPivot/GunMount") as Node3D
	if tank_turret == null or tank_gun == null or absf(tank_turret.rotation_degrees.y - 37.0) > 0.01 or absf(tank_gun.rotation_degrees.x - 12.0) > 0.01:
		return "tank turret or gun did not articulate independently"

	var artillery: Node3D = samples["artillery"]
	if not bool(scene.call("set_heavy_visual_weapon_pose", artillery, -28.0, 25.0)):
		return "artillery weapon pose rejected"
	var artillery_turret := artillery.get_node_or_null("ArtilleryModel/TurretPivot") as Node3D
	var artillery_gun := artillery.get_node_or_null("ArtilleryModel/TurretPivot/GunMount") as Node3D
	if artillery_turret == null or artillery_gun == null or absf(artillery_turret.rotation_degrees.y + 28.0) > 0.01 or absf(artillery_gun.rotation_degrees.x - 25.0) > 0.01:
		return "artillery traverse or elevation did not articulate independently"

	var launcher: Node3D = samples["rocket_launcher"]
	if not bool(scene.call("set_heavy_visual_weapon_pose", launcher, 55.0, 32.0)):
		return "rocket launcher weapon pose rejected"
	var launcher_pivot := launcher.get_node_or_null("LauncherModel/LauncherPivot") as Node3D
	var elevation_pivot := launcher.get_node_or_null("LauncherModel/LauncherPivot/ElevationPivot") as Node3D
	if launcher_pivot == null or elevation_pivot == null or absf(launcher_pivot.rotation_degrees.y - 55.0) > 0.01 or absf(elevation_pivot.rotation_degrees.x + 32.0) > 0.01:
		return "rocket launcher traverse or elevation did not articulate independently"

	scene.call("set_heavy_visual_weapon_pose", tank, 0.0, 0.0)
	scene.call("set_heavy_visual_weapon_pose", artillery, 0.0, 0.0)
	scene.call("set_heavy_visual_weapon_pose", launcher, 0.0, 0.0)
	return ""
