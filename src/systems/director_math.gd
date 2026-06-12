class_name DirectorMath
extends RefCounted
## Чистая математика Escalation Director'а (BRIEF 3.3) — без состояния,
## полностью покрыта GUT. Сам Director (автолоад) — тонкая обёртка с таймерами.

const TOP_FLOOR: int = 9

const TIER2_TENSION: float = 22.0
const TIER3_TENSION: float = 55.0
const TIER3_FLOOR: int = 7          # T3 — только финальная треть (этажи 7-9)

## Авторская базовая кривая: пол Tension растёт с этажом.
## Этаж 1 -> 6, этаж 9 -> 66; событothers поверх (offset).
static func base_tension(floor_value: int) -> float:
	return clampf(6.0 + 7.5 * float(clampi(floor_value, 1, TOP_FLOOR) - 1), 0.0, 100.0)

## Итоговый Tension: база по этажу + событийный сдвиг.
static func combine(floor_value: int, offset: float) -> float:
	return clampf(base_tension(floor_value) + offset, 0.0, 100.0)

## Гейт тиров: T1 всегда; T2 от TIER2_TENSION; T3 — Tension+финальная треть.
static func max_tier(tension: float, floor_value: int) -> int:
	if tension >= TIER3_TENSION and floor_value >= TIER3_FLOOR:
		return 3
	if tension >= TIER2_TENSION:
		return 2
	return 1

## Микс 3-слойного эмбиента (Section 6): линейные громкости L1/L2/L3.
## L1 всегда; L2 вплывает на 25..60; L3 — на 55..95. relief глушит верхний слой.
static func ambience_mix(tension: float, relief_active: bool) -> Vector3:
	var l2 := clampf(inverse_lerp(25.0, 60.0, tension), 0.0, 1.0)
	var l3 := clampf(inverse_lerp(55.0, 95.0, tension), 0.0, 1.0)
	if relief_active:
		if l3 > 0.0:
			l3 = 0.0       # после T3/сброса — выдох: верхний слой умолкает
		else:
			l2 = minf(l2, 0.25)
	return Vector3(1.0, l2, l3)

## Условия скер-слота 1 (E2-эскалация, середина забега, единожды).
static func scare1_ready(fired: bool, floor_value: int, tension: float) -> bool:
	return not fired and floor_value >= 4 and floor_value <= 6 and tension >= 45.0

## Условия скер-слота 2 (первая мёртвая лампа + дыхание, начало финала).
static func scare2_ready(fired: bool, floor_value: int) -> bool:
	return not fired and floor_value == 8
