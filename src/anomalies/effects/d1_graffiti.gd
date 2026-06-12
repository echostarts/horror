extends AnomalyEffect
## D1 (TEXT, T2): граффити на стене марша теперь читается «НЕ ПОДНИМАЙСЯ».

func post_build(_landing: FlightModule, flight: FlightModule) -> void:
	flight.set_graffiti("НЕ ПОДНИМАЙСЯ")
