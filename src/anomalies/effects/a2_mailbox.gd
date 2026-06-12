extends AnomalyEffect
## A2 (OBJECT, T1): почтовый ящик открыт и переполнен одинаковыми письмами.

func post_build(landing: FlightModule, _flight: FlightModule) -> void:
	landing.show_mailbox_overflow()
