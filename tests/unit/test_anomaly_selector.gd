extends GutTest
## Выбор аномалий: детерминизм по seed, фильтр min_tension, отсутствие
## мгновенных повторов (BRIEF 3.2/3.3).

func _make_defs() -> Array[AnomalyDef]:
	var defs: Array[AnomalyDef] = []
	for entry: Dictionary in [
		{"id": &"alpha", "w": 1.0, "mt": 0.0, "tier": 1, "strobe": false},
		{"id": &"beta", "w": 2.0, "mt": 0.0, "tier": 1, "strobe": false},
		{"id": &"gamma_gated", "w": 1.0, "mt": 50.0, "tier": 1, "strobe": false},
		{"id": &"delta_t3", "w": 1.0, "mt": 0.0, "tier": 3, "strobe": false},
		{"id": &"epsilon_strobe", "w": 1.0, "mt": 0.0, "tier": 1, "strobe": true},
	]:
		var def := AnomalyDef.new()
		def.id = entry["id"]
		def.spawn_weight = entry["w"]
		def.min_tension = entry["mt"]
		def.tier = entry["tier"]
		def.strobe = entry["strobe"]
		defs.append(def)
	return defs

func _roll_sequence(seed_value: int, count: int, tension: float,
		max_tier: int = 3, allow_strobe: bool = true) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var selector := AnomalySelector.new(rng, _make_defs())
	var sequence: Array = []
	for i: int in count:
		var def := selector.roll(tension, max_tier, allow_strobe)
		sequence.append(def.id if def != null else &"")
	return sequence

func test_same_seed_same_sequence() -> void:
	assert_eq(_roll_sequence(1234, 60, 30.0), _roll_sequence(1234, 60, 30.0))

func test_different_seed_differs() -> void:
	assert_ne(_roll_sequence(1, 60, 30.0), _roll_sequence(2, 60, 30.0))

func test_min_tension_gates_anomaly() -> void:
	for id: StringName in _roll_sequence(777, 200, 0.0):
		assert_ne(id, &"gamma_gated", "T-гейт по min_tension нарушен")

func test_high_tension_unlocks() -> void:
	var found := false
	for id: StringName in _roll_sequence(777, 300, 90.0):
		if id == &"gamma_gated":
			found = true
	assert_true(found, "при высокой Tension гейт должен открыться")

func test_no_immediate_repeat() -> void:
	var prev: StringName = &""
	for id: StringName in _roll_sequence(42, 300, 30.0):
		if id != &"" and prev != &"":
			assert_ne(id, prev, "одинаковая аномалия два сегмента подряд")
		if id != &"":
			prev = id

func test_tier_gate_excludes_t3() -> void:
	for id: StringName in _roll_sequence(99, 250, 90.0, 2):
		assert_ne(id, &"delta_t3", "T3 при max_tier=2 запрещён")

func test_tier_gate_opens_t3() -> void:
	var found := false
	for id: StringName in _roll_sequence(99, 300, 90.0, 3):
		if id == &"delta_t3":
			found = true
	assert_true(found, "T3 при max_tier=3 должен выпадать")

func test_photosensitivity_excludes_strobe() -> void:
	for id: StringName in _roll_sequence(55, 250, 90.0, 3, false):
		assert_ne(id, &"epsilon_strobe", "строб в режиме фоточувствительности")

func test_empty_defs_roll_null() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var selector := AnomalySelector.new(rng, [] as Array[AnomalyDef])
	for i: int in 20:
		assert_null(selector.roll(50.0))
