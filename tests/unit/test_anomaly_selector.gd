extends GutTest
## Выбор аномалий: детерминизм по seed, фильтр min_tension, отсутствие
## мгновенных повторов (BRIEF 3.2/3.3).

func _make_defs() -> Array[AnomalyDef]:
	var defs: Array[AnomalyDef] = []
	for entry: Dictionary in [
		{"id": &"alpha", "w": 1.0, "mt": 0.0},
		{"id": &"beta", "w": 2.0, "mt": 0.0},
		{"id": &"gamma_gated", "w": 1.0, "mt": 50.0},
	]:
		var def := AnomalyDef.new()
		def.id = entry["id"]
		def.spawn_weight = entry["w"]
		def.min_tension = entry["mt"]
		defs.append(def)
	return defs

func _roll_sequence(seed_value: int, count: int, tension: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var selector := AnomalySelector.new(rng, _make_defs())
	var sequence: Array = []
	for i: int in count:
		var def := selector.roll(tension)
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

func test_empty_defs_roll_null() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var selector := AnomalySelector.new(rng, [] as Array[AnomalyDef])
	for i: int in 20:
		assert_null(selector.roll(50.0))
