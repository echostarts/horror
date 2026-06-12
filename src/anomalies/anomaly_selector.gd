class_name AnomalySelector
extends RefCounted
## Детерминированный выбор аномалии для сегмента. RNG инжектится снаружи
## (в рантайме — сидированный RNG Director'а), поэтому класс тестируем
## и воспроизводим по seed (BRIEF 3.3).

const ANOMALY_CHANCE: float = 0.45  # доля сегментов с аномалией; тюнинг в M2

var _rng: RandomNumberGenerator
var _defs: Array[AnomalyDef]
var _last_id: StringName = &""

func _init(rng: RandomNumberGenerator, defs: Array[AnomalyDef]) -> void:
	_rng = rng
	_defs = defs

## Возвращает AnomalyDef или null (сегмент без аномалии).
func roll(tension: float) -> AnomalyDef:
	if _defs.is_empty() or _rng.randf() >= ANOMALY_CHANCE:
		return null
	var pool: Array[AnomalyDef] = []
	for def: AnomalyDef in _defs:
		if def.min_tension <= tension and def.id != _last_id:
			pool.append(def)
	if pool.is_empty():
		return null
	var total := 0.0
	for def: AnomalyDef in pool:
		total += def.spawn_weight
	var pick := _rng.randf() * total
	for def: AnomalyDef in pool:
		pick -= def.spawn_weight
		if pick <= 0.0:
			_last_id = def.id
			return def
	_last_id = pool[-1].id
	return pool[-1]

static func load_all(dir_path: String = "res://content/anomalies") -> Array[AnomalyDef]:
	var defs: Array[AnomalyDef] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("AnomalySelector: каталог %s не открыт" % dir_path)
		return defs
	for file: String in dir.get_files():
		# В экспортированном pck ресурсы видны как .tres.remap — убираем хвост.
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			var def := load(dir_path.path_join(name)) as AnomalyDef
			if def != null:
				defs.append(def)
	defs.sort_custom(func(a: AnomalyDef, b: AnomalyDef) -> bool: return String(a.id) < String(b.id))
	return defs
