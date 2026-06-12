extends AnomalyEffect
## A3 (OBJECT, T2): велосипед исчез — остался только закрытый замок на стояке.

func post_build(landing: FlightModule, _flight: FlightModule) -> void:
	landing.set_bike_missing()
