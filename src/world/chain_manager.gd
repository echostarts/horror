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
var _defs: Array[AnomalyDef] = []
var _forced_id: String = OS.get_environment("ETAZH9_FORCE")  # dev: форс аномалии
var _question: AnomalyDef = null # аномалия текущего вопроса Q(0) (null = чисто)
var _effect: AnomalyEffect = null
var _flight_event_fired: bool = false
var _loop := LoopManager.new()
var _selector: AnomalySelector
var _player: Player
var _fx: TransitionLayer
var _busy: bool = false
var _finished: bool = false
## Первый вопрос забега всегда чистый: игрок должен увидеть «норму», прежде
## чем искать отклонения (грамматика Exit 8, Pillar 5 — честность).
var _first_question: bool = true
## Кулдаун (физ. кадры) после re-anchor: перемещение/ребилд модулей рождает
## фантомные body_entered кадром позже — реальный траверс занимает секунды.
var _ignore_frames: int = 0

func _ready() -> void:
	add_to_group(&"chain_manager")
	_player = get_node(player_path) as Player
	EventBus.run_started.connect(_on_run_started)
	_build_caps()

func _physics_process(_delta: float) -> void:
	if _ignore_frames > 0:
		_ignore_frames -= 1

func _on_run_started(_seed_value: int) -> void:
	# Строимся только ПОСЛЕ старта забега: RNG Director'а уже засеян.
	_fx = get_tree().get_first_node_in_group(&"transition_layer") as TransitionLayer
	_defs = AnomalySelector.load_all()
	_selector = AnomalySelector.new(Director.rng(), _defs)
	_loop.reset_to_start()
	_finished = false
	_first_question = true
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
	_ignore_frames = 5
	# Единственный разрешённый хинт — субтитром на первом пролёте (Section 8).
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		EventBus.subtitle_requested.emit(
			"Что-то не так на этаже — спустись на пролёт. Всё как всегда — поднимайся.", 6.0))

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

## Стейдж вопроса Q(0): roll аномалии (через гейты Director'а), пересборка
## марша-носителя (модуль +1) с pre_build, затем post_build на оба носителя.
## Вызывается только под глитчем/ревайндом — носители выше игрока или
## меняются точечными хуками.
func _stage_question() -> void:
	if _effect != null:
		_effect.teardown()   # глобальные побочки (например, эхо шагов F1)
	_flight_event_fired = false
	if not _forced_id.is_empty():
		# Dev-режим (ETAZH9_FORCE=id): одна и та же аномалия на каждом сегменте.
		_question = null
		for def: AnomalyDef in _defs:
			if String(def.id) == _forced_id:
				_question = def
		_effect = _question.make_effect() if _question != null else null
	elif _first_question:
		_question = null     # первый сегмент забега — эталон «нормы»
		_effect = null
	elif Director.consume_relief():
		_question = null     # relief valve: спокойный пролёт без ролла
		_effect = null
	else:
		_question = _selector.roll(Director.tension,
			Director.allowed_max_tier(), Director.allow_strobe())
		# D2 не читается на симметричных цифрах трафарета (этажи 1 и 8).
		if _question != null and _question.id == &"d2_mirrored_stencil" \
				and _loop.floor_number in [1, 8]:
			_question = _selector.roll(Director.tension,
				Director.allowed_max_tier(), Director.allow_strobe())
			if _question != null and _question.id == &"d2_mirrored_stencil":
				_question = null
		_effect = _question.make_effect() if _question != null else null
	_first_question = false
	var flight_cfg := _baseline_cfg(1)
	if _effect != null:
		_effect.pre_build(flight_cfg)
	var flight: FlightModule = _modules[1]
	flight.build(flight_cfg)
	# Площадка под игроком возвращается к базе точечными хуками (без ребилда),
	# чтобы отыгранный вопрос не наслаивался на новый.
	(_modules[0] as FlightModule).reset_landing_props()
	if _effect != null:
		_effect.post_build(_modules[0], flight)
		Director.maybe_trigger_silence(_question.tier)
		EventBus.anomaly_spawned.emit(_question.id)
	else:
		EventBus.anomaly_cleared.emit(&"")

# ------------------------------------------------------------------ commit

func _on_landing_entered(module: FlightModule) -> void:
	# Коммит легален только с соседней площадки (±1) и вне кулдауна re-anchor.
	if _busy or _finished or _ignore_frames > 0 or absi(module.level) != 1:
		return
	_busy = true
	# Area-коллбек приходит из физики — менять дерево можно только deferred.
	_commit.call_deferred(module.level)

func _on_flight_entered(module: FlightModule) -> void:
	if module.level != 1 or _finished or _ignore_frames > 0:
		return
	if Director.try_fire_scare1():
		_do_scare1(module)
	if _effect != null and not _flight_event_fired:
		_flight_event_fired = true
		_effect.on_flight_entered(module)

## Скер-слот 1: E2-эскалация — силуэт ближе, чем позволяет физика, один кадр,
## жёсткий стингер (в режиме фоточувствительности — дольше и без глитча).
func _do_scare1(module: FlightModule) -> void:
	var no_strobe := not Director.allow_strobe()
	module.flash_silhouette_close(0.55 if no_strobe else 0.18)
	AudioDirector.play_event(&"PLACEHOLDER_sting",
		module.to_global(Vector3(FlightModule.FLIGHT_X,
			FlightModule.TOTAL_RISE * 0.6 + 1.2, FlightModule.TOTAL_RUN * 0.6)))
	_player.add_shake(0.25)
	if not no_strobe:
		_fx.glitch(0.1)

## Скер-слот 2: первая мёртвая лампа прямо за спиной + дыхание в затылок.
func _do_scare2() -> void:
	await get_tree().create_timer(0.7).timeout
	var module: FlightModule = _modules[0]
	module.lamp_off()
	AudioDirector.play_event(&"PLACEHOLDER_lamp_click", module.lamp_position_global())
	await get_tree().create_timer(0.35).timeout
	AudioDirector.play_breath(1.0)

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
	_ignore_frames = 5
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
		_begin_finale()
		return
	if Director.try_fire_scare2():
		_do_scare2()
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

## Финал «Дом» (BRIEF 3.5, скелет M2): на 9-м дверь №36 приоткрыта, за ней
## тёмная прихожая; подход к двери -> лампа за спиной гаснет -> карточка.
func _begin_finale() -> void:
	_finished = true
	if _effect != null:
		_effect.teardown()
		_effect = null
	_question = null
	var module: FlightModule = _modules[0]
	module.set_door_ajar(1)   # правая дверь девятого этажа = №36
	module.ending_door_reached.connect(_play_ending, CONNECT_ONE_SHOT)

func _play_ending() -> void:
	GameState.phase = GameState.Phase.ENDING
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO
	await get_tree().create_timer(1.1).timeout
	var module: FlightModule = _modules[0]
	module.lamp_off()
	AudioDirector.play_event(&"PLACEHOLDER_lamp_click", module.lamp_position_global())
	await get_tree().create_timer(1.7).timeout
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
	return _busy or _ignore_frames > 0

func debug_module(level: int) -> FlightModule:
	return _modules.get(level)

func debug_question_id() -> StringName:
	return _question.id if _question != null else &""
