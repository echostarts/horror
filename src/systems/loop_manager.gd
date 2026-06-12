class_name LoopManager
extends RefCounted
## Чистая логика лупа (BRIEF 3.1): (наличие аномалии, направление) -> вердикт.
## Никаких ссылок на сцену/рендер/звук — класс полностью тестируем GUT'ом.
## Сценой управляет ChainManager, он же применяет результат к GameState.

enum Verdict { ADVANCE, RESET }

const FIRST_FLOOR: int = 1
const TOP_FLOOR: int = 9

const DIR_UP: int = 1
const DIR_DOWN: int = -1

var floor_number: int = FIRST_FLOOR

## Правило: аномалия есть + пошёл ВНИЗ -> верно; аномалии нет + пошёл ВВЕРХ -> верно;
## иначе -> сброс на первый этаж.
static func judge(anomaly_present: bool, direction: int) -> Verdict:
	assert(direction == DIR_UP or direction == DIR_DOWN, "direction должен быть +1/-1")
	var correct := (anomaly_present and direction == DIR_DOWN) \
		or (not anomaly_present and direction == DIR_UP)
	return Verdict.ADVANCE if correct else Verdict.RESET

## Применяет вердикт к состоянию этажа. Возвращает словарь:
## { "verdict": Verdict, "floor": int, "finished": bool }.
func commit(anomaly_present: bool, direction: int) -> Dictionary:
	var verdict := judge(anomaly_present, direction)
	if verdict == Verdict.ADVANCE:
		floor_number = mini(floor_number + 1, TOP_FLOOR)
	else:
		floor_number = FIRST_FLOOR
	return {
		"verdict": verdict,
		"floor": floor_number,
		"finished": floor_number >= TOP_FLOOR,
	}

func reset_to_start() -> void:
	floor_number = FIRST_FLOOR
