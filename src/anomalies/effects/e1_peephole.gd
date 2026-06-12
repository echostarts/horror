extends AnomalyEffect
## E1 (ENTITY, T2): глазок правой двери темнеет, когда проходишь мимо.

func post_build(landing: FlightModule, _flight: FlightModule) -> void:
	landing.set_peephole_watcher(1)
