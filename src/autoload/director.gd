extends Node
## Escalation Director (lite) — скелет M0; полная логика (тиры аномалий,
## relief valves, silence events, скеры) приходит в M2.
##
## Владеет Tension 0..100 и сидированным RNG: при одинаковом seed весь
## забег обязан быть воспроизводимым (QA-репро, BRIEF Section 3.3).

const TENSION_MIN: float = 0.0
const TENSION_MAX: float = 100.0

var tension: float = 0.0:
	set(value):
		var clamped := clampf(value, TENSION_MIN, TENSION_MAX)
		if not is_equal_approx(clamped, tension):
			tension = clamped
			EventBus.tension_changed.emit(tension)

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)

func _on_run_started(seed_value: int) -> void:
	_rng.seed = seed_value
	tension = 0.0

## Вся случайность Director'а обязана идти через roll()/roll_range() —
## иначе ломается детерминизм по seed.
func roll() -> float:
	return _rng.randf()

func roll_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)
