extends AnomalyEffect
## F1 (META, T1): у шагов появляется эхо не в такт. Глобальная побочка в
## AudioDirector — снимается teardown'ом при рестейдже вопроса.

func post_build(_landing: FlightModule, _flight: FlightModule) -> void:
	AudioDirector.set_footstep_echo(true)

func teardown() -> void:
	AudioDirector.set_footstep_echo(false)
