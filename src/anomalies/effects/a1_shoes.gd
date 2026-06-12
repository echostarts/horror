extends AnomalyEffect
## A1 (OBJECT, T1): лишняя пара обуви у двери №36 — на площадке, где стоит игрок.

func post_build(landing: FlightModule, _flight: FlightModule) -> void:
	landing.show_extra_shoes()
