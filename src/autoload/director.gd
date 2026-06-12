extends Node
## Escalation Director (BRIEF 3.3). Состояние Tension = база по этажу
## (DirectorMath.base_tension) + событийный offset с затуханием.
## Выходы: гейт тиров аномалий, микс 3-слойного эмбиента, relief valves
## (≥2 спокойных пролёта после T3/сброса), silence events (1-2 раза за забег,
## 5-10 c перед T2+), шедулинг двух скер-слотов, дальние ваншоты.
##
## Детерминизм: геймплейный RNG (_rng) расходуется ТОЛЬКО AnomalySelector'ом.
## Тайминги презентации (ваншоты, silence, скеры) — на _ambient_rng.

const OFFSET_DECAY: float = 1.1        # ед./с к нулю
const IDLE_THRESHOLD: float = 15.0     # сек неподвижности до «дом смотрит»
const IDLE_CREEP: float = 0.45         # ед./с к offset при затянувшемся idle

var tension: float = 0.0:
	set(value):
		var clamped := clampf(value, 0.0, 100.0)
		if not is_equal_approx(clamped, tension):
			tension = clamped
			EventBus.tension_changed.emit(tension)

var _rng := RandomNumberGenerator.new()
var _ambient_rng := RandomNumberGenerator.new()
var _offset: float = 0.0
var _relief_left: int = 0
var _silence_budget: int = 0
var _silence_active: bool = false
var _scare1_fired: bool = false
var _scare2_fired: bool = false
var _idle_time: float = 0.0
var _next_oneshot_in: float = 30.0
var _player: CharacterBody3D

func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.verdict_resolved.connect(_on_verdict)

## Геймплейный RNG: вся случайность вердиктного контента — только отсюда.
func rng() -> RandomNumberGenerator:
	return _rng

func _on_run_started(seed_value: int) -> void:
	_rng.seed = seed_value
	_ambient_rng.seed = seed_value + 1
	_offset = 0.0
	_relief_left = 0
	_silence_budget = _ambient_rng.randi_range(1, 2)
	_silence_active = false
	_scare1_fired = false
	_scare2_fired = false
	_idle_time = 0.0
	_player = null
	tension = DirectorMath.base_tension(1)
	_next_oneshot_in = _ambient_rng.randf_range(20.0, 35.0)

func _on_verdict(correct: bool, _floor_value: int) -> void:
	if correct:
		_offset += 4.0
	else:
		_offset += 16.0   # штраф за сброс (BRIEF 3.1)
		_relief_left = maxi(_relief_left, 2)

func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.RUN:
		return
	_offset = maxf(_offset - OFFSET_DECAY * delta, 0.0)
	_update_idle(delta)
	tension = DirectorMath.combine(GameState.current_floor, _offset)
	_oneshot_scheduler(delta)

func _update_idle(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
		return
	if _player.velocity.length_squared() < 0.04:
		_idle_time += delta
		if _idle_time > IDLE_THRESHOLD:
			_offset += IDLE_CREEP * delta   # вход «time frozen in place»
	else:
		_idle_time = 0.0

# ------------------------------------------------- выходы для ChainManager

func allowed_max_tier() -> int:
	return DirectorMath.max_tier(tension, GameState.current_floor)

func allow_strobe() -> bool:
	return not SettingsService.get_bool(&"video/photosensitivity_mode")

func relief_active() -> bool:
	return _relief_left > 0

## Спокойный пролёт по требованию relief valve. Вызывается при стейдже вопроса.
func consume_relief() -> bool:
	if _relief_left <= 0:
		return false
	_relief_left -= 1
	return true

func force_relief() -> void:
	_relief_left = maxi(_relief_left, 2)

## Тишина как оружие: вызывается при стейдже T2+ вопроса. Жёсткий cut всего
## эмбиента на 5-10 c, пока игрок идёт навстречу аномалии.
func maybe_trigger_silence(question_tier: int) -> void:
	if question_tier < 2 or _silence_budget <= 0 or _silence_active:
		return
	if _ambient_rng.randf() > 0.55:
		return
	_silence_budget -= 1
	_silence_active = true
	var duration := _ambient_rng.randf_range(5.0, 10.0)
	AudioDirector.set_hard_silence(true)
	EventBus.silence_event_started.emit(duration)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		_silence_active = false
		AudioDirector.set_hard_silence(false)
		EventBus.silence_event_ended.emit())

func is_silence_active() -> bool:
	return _silence_active

func current_ambience_mix() -> Vector3:
	if _silence_active:
		return Vector3.ZERO
	return DirectorMath.ambience_mix(tension, relief_active())

## Скер-слот 1: ChainManager спрашивает при входе игрока в марш вверх.
func try_fire_scare1() -> bool:
	if not DirectorMath.scare1_ready(_scare1_fired, GameState.current_floor, tension):
		return false
	_scare1_fired = true
	_offset += 18.0
	force_relief()
	EventBus.scare_triggered.emit(1)
	return true

## Скер-слот 2: первая мёртвая лампа + дыхание в затылок (этаж 8).
func try_fire_scare2() -> bool:
	if not DirectorMath.scare2_ready(_scare2_fired, GameState.current_floor):
		return false
	_scare2_fired = true
	_offset += 12.0
	EventBus.scare_triggered.emit(2)
	return true

## Дальний позиционный ваншот + субтитр: приучает игрока к паре «звук+титр»
## (без этой привычки META-аномалия F2 не читается).
func _oneshot_scheduler(delta: float) -> void:
	_next_oneshot_in -= delta
	if _next_oneshot_in > 0.0 or _silence_active:
		return
	_next_oneshot_in = lerpf(45.0, 22.0, tension / 100.0) \
		+ _ambient_rng.randf_range(-6.0, 6.0)
	if _player == null:
		return
	var offset := Vector3(_ambient_rng.randf_range(-2.0, 2.0),
		_ambient_rng.randf_range(5.0, 9.0), _ambient_rng.randf_range(-2.0, 2.0))
	AudioDirector.play_event(&"PLACEHOLDER_door_slam", _player.global_position + offset)
	EventBus.subtitle_requested.emit("[хлопок двери наверху]", 2.2)
