extends AnomalyEffect
## C1 (LIGHT, T1): лампа площадки горит тёплым вместо холодного.

func post_build(landing: FlightModule, _flight: FlightModule) -> void:
	landing.set_lamp_warm()
