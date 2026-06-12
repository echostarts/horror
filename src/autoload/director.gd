extends Node
## Escalation Director (lite). M1: простая динамика Tension + редкие дальние
## ваншоты с субтитрами (фон для аномалии F2). Полная версия с relief valves,
## silence events и скер-слотами — M2 (BRIEF 3.3).
##
## Детерминизм: геймплейный RNG (_rng) сеется seed'ом забега, и его порядок
## расходуется ТОЛЬКО выбором аномалий (AnomalySelector). Презентационный
## шедулер ваншотов живёт на отдельном RNG и на вердикты не влияет.

const TENSION_MIN: float = 0.0
const TENSION_MAX: float = 100.0

var tension: float = 0.0:
	set(value):
		var clamped := clampf(value, TENSION_MIN, TENSION_MAX)
		if not is_equal_approx(clamped, tension):
			tension = clamped
			EventBus.tension_changed.emit(tension)

var _rng := RandomNumberGenerator.new()
var _ambient_rng := RandomNumberGenerator.new()
var _next_oneshot_in: float = 30.0

func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.verdict_resolved.connect(_on_verdict)

## Геймплейный RNG: вся случайность вердиктного контента — только отсюда.
func rng() -> RandomNumberGenerator:
	return _rng

func _on_run_started(seed_value: int) -> void:
	_rng.seed = seed_value
	_ambient_rng.seed = seed_value + 1
	tension = 0.0
	_next_oneshot_in = _ambient_rng.randf_range(20.0, 35.0)

func _on_verdict(correct: bool, floor_value: int) -> void:
	if correct:
		tension += 3.5 + 0.5 * float(floor_value)
	else:
		tension += 14.0   # штраф за сброс (BRIEF 3.1)

func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.RUN:
		return
	# TODO(M2): авторская кривая, relief valves, silence events, скер-слоты.
	var floor_baseline := minf(float(GameState.current_floor) * 2.5, TENSION_MAX)
	tension = maxf(tension - 0.3 * delta, floor_baseline)
	_oneshot_scheduler(delta)

## Дальний позиционный ваншот + субтитр: приучает игрока к паре «звук+титр»
## (без этой привычки META-аномалия F2 не читается).
func _oneshot_scheduler(delta: float) -> void:
	_next_oneshot_in -= delta
	if _next_oneshot_in > 0.0:
		return
	_next_oneshot_in = lerpf(45.0, 22.0, tension / 100.0) \
		+ _ambient_rng.randf_range(-6.0, 6.0)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var offset := Vector3(_ambient_rng.randf_range(-2.0, 2.0),
		_ambient_rng.randf_range(5.0, 9.0), _ambient_rng.randf_range(-2.0, 2.0))
	AudioDirector.play_event(&"PLACEHOLDER_door_slam", player.global_position + offset)
	EventBus.subtitle_requested.emit("[хлопок двери наверху]", 2.2)
