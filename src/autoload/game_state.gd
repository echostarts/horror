extends Node
## Авторитетное состояние забега: этаж, seed, фаза, серии. Чистые данные —
## никакого рендера и звука. Этаж мутируется ТОЛЬКО через apply_verdict
## (вердикты считает LoopManager, оркестрирует ChainManager).

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

func apply_verdict(correct: bool, floor_value: int) -> void:
	current_floor = floor_value
	if correct:
		correct_streak += 1
	else:
		correct_streak = 0
		mistakes += 1
