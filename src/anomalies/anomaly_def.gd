class_name AnomalyDef
extends Resource
## Описание аномалии (BRIEF 3.2). Контент = данные: добавление аномалии №16 —
## это новый .tres + один скрипт эффекта, без хирургии движка.

@export var id: StringName
@export var display_name: String
@export var category: StringName        # OBJECT / SPATIAL / LIGHT / TEXT / ENTITY / META
@export_range(1, 3) var tier: int = 1   # T3 гейтится финальной третью слайса (M2)
@export var spawn_weight: float = 1.0
@export var min_tension: float = 0.0
## Строб-класс мерцания: в режиме фоточувствительности (Section 9) Director
## не допускает такие аномалии — селектор подставляет другие.
@export var strobe: bool = false
@export var conflicts_with: Array[StringName] = []
@export var effect_script: GDScript     # extends AnomalyEffect
@export var audio_cue: AudioStream      # опционально

func make_effect() -> AnomalyEffect:
	assert(effect_script != null, "У аномалии %s нет effect_script" % id)
	var effect: AnomalyEffect = effect_script.new()
	return effect
