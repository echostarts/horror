extends Node
## Фронтенд аудио-архитектуры. ВЕСЬ геймплейный звук идёт через этот автолоад —
## сырых play() в геймплейном коде быть не должно (BRIEF Section 6).
##
## Reverb-шина — общий «бетонный» хвост. В Godot нет настоящих aux-send'ов,
## поэтому позиционные ваншоты в M4 будут дублироваться на Reverb-шину
## вторым плеером пула (решение зафиксировано в ARCHITECTURE.md, D-004).

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_AMBIENCE := &"Ambience"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const BUS_REVERB := &"Reverb"

const PITCH_JITTER: float = 0.04   # ±4% (BRIEF Section 6, footsteps)
const POOL_SIZE: int = 12

var _pool: Array[AudioStreamPlayer3D] = []
## RNG презентационного слоя: на детерминизм геймплея (Director) не влияет.
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	for i: int in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = BUS_SFX
		add_child(player)
		_pool.append(player)

## Единственная точка входа для рандомизированных SFX: случайный стрим из пула
## + питч-джиттер. Позиция — глобальная, мир общий с SubViewport (см. ARCHITECTURE.md).
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

func _acquire() -> AudioStreamPlayer3D:
	for player: AudioStreamPlayer3D in _pool:
		if not player.playing:
			return player
	return null
