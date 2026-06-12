extends Node
## Фронтенд аудио-архитектуры. ВЕСЬ геймплейный звук идёт через этот автолоад —
## сырых play() в геймплейном коде быть не должно (BRIEF Section 6).
##
## M1: библиотека процедурных PLACEHOLDER_-звуков (PlaceholderSfx) подключена
## через ФИНАЛЬНУЮ архитектуру: к M4 меняются только файлы в библиотеке.
## Reverb-шина — общий «бетонный» хвост; в Godot нет aux-send'ов, дублирование
## ваншотов на Reverb придёт в M4 (ARCHITECTURE.md, D-004).

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_AMBIENCE := &"Ambience"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const BUS_REVERB := &"Reverb"

const PITCH_JITTER: float = 0.04   # ±4% (BRIEF Section 6)
const POOL_SIZE: int = 12

var _pool: Array[AudioStreamPlayer3D] = []
var _library: Dictionary = {}
var _ui_player: AudioStreamPlayer
var _breath_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
## RNG презентационного слоя: на детерминизм геймплея (Director) не влияет.
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	for i: int in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = BUS_SFX
		add_child(player)
		_pool.append(player)
	_ui_player = _make_2d_player(BUS_UI)
	_breath_player = _make_2d_player(BUS_SFX)
	_ambience_player = _make_2d_player(BUS_AMBIENCE)
	_library = PlaceholderSfx.build_library()
	_ambience_player.stream = (_library[&"PLACEHOLDER_amb_l1"] as Array[AudioStream])[0]
	_ambience_player.volume_db = -16.0
	_ambience_player.play()

func _make_2d_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player

## Единственная точка входа для рандомизированных позиционных SFX.
func play_varied(streams: Array[AudioStream], position: Vector3, bus: StringName = BUS_SFX) -> void:
	if streams.is_empty():
		push_warning("AudioDirector.play_varied: пустой пул стримов")
		return
	var player := _acquire()
	if player == null:
		return  # пул исчерпан: молча роняем ваншот, не аллоцируем в hot path
	player.bus = bus
	player.global_position = position
	player.stream = streams[_rng.randi_range(0, streams.size() - 1)]
	player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
	player.play()

## Позиционный ваншот из библиотеки по ключу (см. PlaceholderSfx/манифест).
func play_event(key: StringName, position: Vector3, bus: StringName = BUS_SFX) -> void:
	if not _library.has(key):
		push_warning("AudioDirector: нет звука '%s'" % key)
		return
	play_varied(_library[key], position, bus)

func play_footstep(position: Vector3) -> void:
	play_event(&"PLACEHOLDER_footstep_concrete", position)

## Непозиционный UI/системный звук (глитч, перемотка).
func play_ui(key: StringName) -> void:
	if not _library.has(key):
		push_warning("AudioDirector: нет звука '%s'" % key)
		return
	var streams: Array[AudioStream] = _library[key]
	_ui_player.stream = streams[_rng.randi_range(0, streams.size() - 1)]
	_ui_player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
	_ui_player.play()

## Дыхание игрока: intensity 0..1 (стамина/Tension), без UI-полосок (Section 8).
func play_breath(intensity: float) -> void:
	var streams: Array[AudioStream] = _library[&"PLACEHOLDER_breath"]
	_breath_player.stream = streams[_rng.randi_range(0, streams.size() - 1)]
	_breath_player.volume_db = lerpf(-38.0, -8.0, clampf(intensity, 0.0, 1.0))
	_breath_player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
	_breath_player.play()

func _acquire() -> AudioStreamPlayer3D:
	for player: AudioStreamPlayer3D in _pool:
		if not player.playing:
			return player
	return null
