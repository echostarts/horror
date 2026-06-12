extends AnomalyEffect
## E2 (ENTITY, T3): силуэт пролётом выше уходит, когда на него смотришь.
## Единственная T3 слайса — гейтится финальной третью (DirectorMath).

func post_build(_landing: FlightModule, flight: FlightModule) -> void:
	flight.set_silhouette()
