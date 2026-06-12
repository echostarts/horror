extends Node
## Авторитетное состояние забега: этаж, seed, фаза. Чистые данные —
## никакого рендера и звука. Мутировать состояние этажа имеет право
## только Loop Manager (появится в M1).

enum Phase { BOOT, MENU, CALIBRATION, RUN, ENDING }

const FIRST_FLOOR: int = 1
const TOP_FLOOR: int = 9

var phase: Phase = Phase.BOOT
var current_floor: int = FIRST_FLOOR
var run_seed: int = 0
var mistakes: int = 0
var correct_streak: int = 0

func start_run(forced_seed: int = 0) -> void:
	run_seed = forced_seed if forced_seed != 0 else randi()
	current_floor = FIRST_FLOOR
	mistakes = 0
	correct_streak = 0
	phase = Phase.RUN
	EventBus.run_started.emit(run_seed)

func advance_floor() -> void:
	current_floor = mini(current_floor + 1, TOP_FLOOR)
	correct_streak += 1

func reset_run() -> void:
	current_floor = FIRST_FLOOR
	correct_streak = 0
	mistakes += 1
	EventBus.run_reset.emit()
