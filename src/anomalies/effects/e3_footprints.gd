extends AnomalyEffect
## E3 (ENTITY, T2): мокрые босые следы на марше — ведущие ВНИЗ.

func post_build(_landing: FlightModule, flight: FlightModule) -> void:
	flight.set_wet_footprints(true)
