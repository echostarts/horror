extends AnomalyEffect
## C3 (LIGHT, T2): тёплый свет пульсирует из-под левой двери.

func post_build(landing: FlightModule, _flight: FlightModule) -> void:
	landing.set_door_glow(0)
