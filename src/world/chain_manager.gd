class_name ChainManager
extends Node3D
## Тредмил switchback-лестницы: окно из 4 модулей вокруг текущей площадки
## (уровни -1..+2), рециклинг при каждом commit'е, перенос мира к origin
## (re-anchor) под VHS-глитчем. Держит LoopManager (чистые вердикты) и
## AnomalySelector (детерминированный выбор по seed Director'а).
##
## Модель сегментов: вопрос Q(L) = {пропсы площадки L} + {марш модуля L+1}.
## Q судится при прибытии на СОСЕДНЮЮ площадку: вверх -> judge(Q, UP),
## вниз -> judge(Q, DOWN). Подробно — ARCHITECTURE.md.

const WINDOW: Array[int] = [-1, 0, 1, 2]

@export var player_path: NodePath

var _modules: Dictionary = {}    # level -> FlightModule
var _question: AnomalyDef = null # аномалия текущего вопроса Q(0) (null = чисто)
var _effect: AnomalyEffect = null
var _flight_event_fired: bool = false
var _loop := LoopManager.new()
var _selector: AnomalySelector
var _player: Player
var _fx: TransitionLayer
var _busy: bool = false
var _finished: bool = false

func _ready() -> void:
	add_to_group(&"chain_manager")
	_player = get_node(player_path) as Player
	EventBus.run_started.connect(_on_run_started)
	_build_caps()

func _on_run_started(_seed_value: int) -> void:
	# Строимся только ПОСЛЕ старта забега: RNG Director'а уже засеян.
	_fx = get_tree().get_first_node_in_group(&"transition_layer") as TransitionLayer
	_selector = AnomalySelector.new(Director.rng(), AnomalySelector.load_all())
	_loop.reset_to_start()
	_finished = false
	for level: int in WINDOW:
		if not _modules.has(level):
			var module := FlightModule.new()
			module.name = "Module%+d" % level
			add_child(module)
			module.landing_entered.connect(_on_landing_entered)
			module.flight_entered.connect(_on_flight_entered)
			_modules[level] = module
	_rebuild_all_baseline()
	_modules[0].reveal_stencil(_loop.floor_number)
	_stage_question()

## Полная пересборка окна в базовое состояние вокруг текущего этажа.
func _rebuild_all_baseline() -> void:
	for level: int in WINDOW:
		var module: FlightModule = _modules[level]
		module.level = level
		module.transform = chain_pow(level)
		module.build(_baseline_cfg(level))

func _baseline_cfg(level: int) -> SegmentConfig:
	var cfg := SegmentConfig.new()
	cfg.floor_label = maxi(_loop.floor_number + level, 1)
	return cfg

## Стейдж вопроса Q(0): roll аномалии, пересборка марша-носителя (модуль +1)
## с pre_build, затем post_build на оба носителя. Вызывается только под
## глитчем/ревайндом — носители выше игрока или меняются точечными хуками.
func _stage_question() -> void:
	_question = _selector.roll(Director.tension)
	_effect = _question.make_effect() if _question != null else null
	_flight_event_fired = false
	var flight_cfg := _baseline_cfg(1)
	if _effect != null:
		_effect.pre_build(flight_cfg)
	var flight: FlightModule = _modules[1]
	flight.build(flight_cfg)
	if _effect != null:
		_effect.post_build(_modules[0], flight)
		EventBus.anomaly_spawned.emit(_question.id)
	else:
		EventBus.anomaly_cleared.emit(&"")

# ------------------------------------------------------------------ commit

func _on_landing_entered(module: FlightModule) -> void:
	if _busy or _finished or module.level == 0:
		return
	_busy = true
	# Area-коллбек приходит из физики — менять дерево можно только deferred.
	_commit.call_deferred(module.level)

func _on_flight_entered(module: FlightModule) -> void:
	if module.level == 1 and _effect != null and not _flight_event_fired:
		_flight_event_fired = true
		_effect.on_flight_entered(module)

func _commit(direction: int) -> void:
	var result := _loop.commit(_question != null, direction)
	var correct: bool = result["verdict"] == LoopManager.Verdict.ADVANCE
	GameState.apply_verdict(correct, result["floor"])
	EventBus.floor_committed.emit(direction)
	EventBus.verdict_resolved.emit(correct, result["floor"])
	if correct:
		_do_advance(direction, result)
	else:
		await _do_reset(direction)
	_busy = false

func _do_advance(direction: int, result: Dictionary) -> void:
	_fx.glitch(0.14)
	_reanchor(direction)
	for level: int in WINDOW:
		_modules[level].set_door_floor(maxi(int(result["floor"]) + level, 1))
	_modules[0].reveal_stencil(result["floor"])
	EventBus.floor_revealed.emit(result["floor"])
	AudioDirector.play_event(&"PLACEHOLDER_note_wire",
		_modules[0].landing_center_global() + Vector3(0.0, 1.5, 0.0), AudioDirector.BUS_SFX)
	if result["finished"]:
		_finish_run()
		return
	_stage_question()

func _do_reset(direction: int) -> void:
	_player.set_physics_process(false)  # не дать уйти вслепую в перестройку
	_player.velocity = Vector3.ZERO
	await _fx.rewind_in()
	_reanchor(direction)
	_rebuild_all_baseline()
	_modules[0].reveal_stencil(_loop.floor_number)
	EventBus.run_reset.emit()
	EventBus.floor_revealed.emit(_loop.floor_number)
	_stage_question()
	await _fx.rewind_out()
	_player.set_physics_process(true)

## Прибывшая площадка становится уровнем 0 в каноне: мир и игрок переносятся
## единым жёстким преобразованием (1 кадр, под глитчем — незаметно).
func _reanchor(direction: int) -> void:
	var arrived: FlightModule = _modules[direction]
	var delta := arrived.transform.affine_inverse()
	_player.teleport(delta)
	var remapped: Dictionary = {}
	for level: int in WINDOW:
		var module: FlightModule = _modules[level]
		module.transform = delta * module.transform
		remapped[level - direction] = module
	_modules = remapped
	# Вышедший из окна модуль переезжает на освободившийся край.
	var vacated: int = -1 - direction if direction > 0 else 2 - direction
	var spare: FlightModule = _modules[vacated]
	_modules.erase(vacated)
	var fresh_level: int = 2 if direction > 0 else -1
	_modules[fresh_level] = spare
	spare.level = fresh_level
	spare.transform = chain_pow(fresh_level)
	spare.build(_baseline_cfg(fresh_level))
	for level: int in WINDOW:
		(_modules[level] as FlightModule).level = level

func _finish_run() -> void:
	_finished = true
	GameState.phase = GameState.Phase.ENDING
	EventBus.run_ended.emit()
	_fx.show_ending()

# ---------------------------------------------------------------- утилиты

static func chain_pow(level: int) -> Transform3D:
	var t := Transform3D.IDENTITY
	var step := FlightModule.chain_step() if level >= 0 else FlightModule.chain_step().affine_inverse()
	for i: int in absi(level):
		t = t * step
	return t

## Чёрные «капы» сверху и снизу тредмила, чтобы в проёме не было пустоты.
func _build_caps() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.01, 0.01, 0.012)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for cap: Dictionary in [
		{"name": "CapTop", "y": FlightModule.TOTAL_RISE * 3.0 + 2.3},
		{"name": "CapBottom", "y": -FlightModule.TOTAL_RISE - 0.3},
	]:
		var box := CSGBox3D.new()
		box.name = cap["name"]
		box.size = Vector3(3.2, 0.2, FlightModule.MODULE_DEPTH + 1.0)
		box.position = Vector3(0.0, cap["y"], FlightModule.MODULE_DEPTH * 0.5)
		box.material = mat
		box.use_collision = cap["name"] == "CapBottom"
		add_child(box)

## Для smoke-тестов и отладки.
func is_busy() -> bool:
	return _busy

func debug_module(level: int) -> FlightModule:
	return _modules.get(level)

func debug_question_id() -> StringName:
	return _question.id if _question != null else &""
