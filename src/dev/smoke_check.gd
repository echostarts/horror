extends Node
## Smoke-проверка для headless-прогонов (создаётся Main'ом только при
## env ETAZH9_SMOKE=1): ждёт приземления капсулы, зажимает move_forward,
## через 6 секунд проверяет, что игрок поднялся по пролёту (y ≈ 2.1),
## и завершает процесс с кодом 0/1. Геймплей не трогает.
##
## Запуск: ETAZH9_SMOKE=1 godot --headless

@onready var _player: CharacterBody3D = get_node("/root/Main/GameViewportContainer/GameViewport/World/Player")

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var landed := _player.is_on_floor()
	var start := _player.global_position
	Input.action_press(&"move_forward")
	await get_tree().create_timer(6.0).timeout
	Input.action_release(&"move_forward")
	var end := _player.global_position
	print("SMOKE landed=%s start=%v end=%v climbed=%.2f" % [landed, start, end, end.y - start.y])
	var ok := landed and end.y > 1.8 and end.z > 4.5
	print("SMOKE RESULT: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
