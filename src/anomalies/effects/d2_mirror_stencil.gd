extends AnomalyEffect
## D2 (TEXT, T1): трафарет этажа зеркальный. ChainManager не ставит D2
## на этажах 1 и 8 (симметричные цифры не читаются как зеркальные).

func post_build(landing: FlightModule, _flight: FlightModule) -> void:
	landing.set_stencil_mirrored()
