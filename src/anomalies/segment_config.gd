class_name SegmentConfig
extends RefCounted
## Конфиг сборки одного сегмента (пролёт + верхняя площадка).
## Базовые значения = канонический модуль; аномалии правят их в pre_build.

var floor_label: int = 1      # этаж, который ПОКАЖУТ двери этого сегмента
var step_count: int = 12
var anomaly: AnomalyDef = null

## Номера квартир: по 2 на площадку, на 9-м этаже — 35/36 (премиса брифа).
func door_numbers() -> Array[int]:
	return [2 * floor_label + 17, 2 * floor_label + 18]
