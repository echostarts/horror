extends AnomalyEffect
## C2 (LIGHT, T2, строб-класс): лампа мерцает в ритме сердцебиения.

func post_build(landing: FlightModule, _flight: FlightModule) -> void:
	landing.set_lamp_flicker_heartbeat()
