extends AnomalyEffect
## B2 (SPATIAL, T2): потолок площадки ниже на ~15% (лампа опускается с ним).

func post_build(landing: FlightModule, _flight: FlightModule) -> void:
	landing.set_low_ceiling()
