extends Node
## Диагностика рендера (env ETAZH9_SHOT=каталог): через 30 кадров сохраняет
## PNG корневого окна и игрового SubViewport, печатает среднюю яркость.
## Опционально env ETAZH9_POSE="x,y,z,yaw_deg,pitch_deg" — поза игрока
## перед снимком (для контактных листов греябокса).

func _ready() -> void:
	for i: int in 10:
		await get_tree().process_frame
	_apply_pose()
	for i: int in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("ETAZH9_SHOT")
	var root_img := get_viewport().get_texture().get_image()
	root_img.save_png(dir.path_join("root.png"))
	var sub := get_node("/root/Main/GameViewportContainer/GameViewport") as SubViewport
	var sub_img := sub.get_texture().get_image()
	sub_img.save_png(dir.path_join("sub.png"))
	print("SHOT root_avg=%.4f sub_avg=%.4f -> %s" % [_avg_luma(root_img), _avg_luma(sub_img), dir])
	get_tree().quit(0)

func _apply_pose() -> void:
	var pose_env := OS.get_environment("ETAZH9_POSE")
	if pose_env.is_empty():
		return
	var parts := pose_env.split(",")
	if parts.size() < 5:
		push_warning("ETAZH9_POSE: ожидаю x,y,z,yaw_deg,pitch_deg")
		return
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	player.rotation = Vector3(0.0, deg_to_rad(float(parts[3])), 0.0)
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(float(parts[4]))

func _avg_luma(img: Image) -> float:
	var total := 0.0
	var step := 8
	var count := 0
	for y: int in range(0, img.get_height(), step):
		for x: int in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			total += (c.r + c.g + c.b) / 3.0
			count += 1
	return total / float(count)
