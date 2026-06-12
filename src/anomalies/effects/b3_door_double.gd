extends AnomalyEffect
## B3 (SPATIAL, T2): дверь заменена дублем №36 — его дверь, не на своём этаже.

func post_build(landing: FlightModule, _flight: FlightModule) -> void:
	landing.set_door_label_override(1, "36")
