extends AnomalyEffect
## B1 (SPATIAL, T1): тринадцать ступеней вместо двенадцати. Общие габариты
## марша неизменны (чейнинг не страдает) — ступени чуть мельче и чаще.

func pre_build(flight_cfg: SegmentConfig) -> void:
	flight_cfg.step_count = 13
