extends AnomalyEffect
## F2 (META, T2): субтитр к звуку, которого не было. Зеркалит штатные дальние
## ваншоты Director'а («[хлопок двери наверху]» + звук) — здесь титр без звука.

func on_flight_entered(_flight: FlightModule) -> void:
	EventBus.subtitle_requested.emit("[хлопок двери наверху]", 2.2)
