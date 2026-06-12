extends GutTest
## Математика Escalation Director'а (BRIEF 3.3): авторская кривая, гейты
## тиров (T3 — финальная треть), микс эмбиента, условия скер-слотов.

func test_base_curve_endpoints() -> void:
	assert_almost_eq(DirectorMath.base_tension(1), 6.0, 0.001)
	assert_almost_eq(DirectorMath.base_tension(9), 66.0, 0.001)

func test_base_curve_monotonic() -> void:
	for floor_value: int in range(1, 9):
		assert_gt(DirectorMath.base_tension(floor_value + 1),
			DirectorMath.base_tension(floor_value))

func test_combine_clamps() -> void:
	assert_almost_eq(DirectorMath.combine(9, 500.0), 100.0, 0.001)
	assert_almost_eq(DirectorMath.combine(1, -500.0), 0.0, 0.001)

func test_tier1_always_allowed() -> void:
	assert_eq(DirectorMath.max_tier(0.0, 1), 1)

func test_tier2_needs_tension() -> void:
	assert_eq(DirectorMath.max_tier(21.9, 5), 1)
	assert_eq(DirectorMath.max_tier(22.0, 5), 2)

func test_tier3_needs_final_third_and_tension() -> void:
	assert_eq(DirectorMath.max_tier(80.0, 6), 2, "T3 до 7 этажа закрыт")
	assert_eq(DirectorMath.max_tier(54.0, 8), 2, "T3 без Tension закрыт")
	assert_eq(DirectorMath.max_tier(55.0, 7), 3)
	assert_eq(DirectorMath.max_tier(70.0, 9), 3)

func test_ambience_mix_low_tension() -> void:
	var mix := DirectorMath.ambience_mix(10.0, false)
	assert_almost_eq(mix.x, 1.0, 0.001)
	assert_almost_eq(mix.y, 0.0, 0.001)
	assert_almost_eq(mix.z, 0.0, 0.001)

func test_ambience_mix_high_tension() -> void:
	var mix := DirectorMath.ambience_mix(95.0, false)
	assert_almost_eq(mix.y, 1.0, 0.001)
	assert_almost_eq(mix.z, 1.0, 0.001)

func test_relief_drops_top_layer() -> void:
	var loud := DirectorMath.ambience_mix(90.0, true)
	assert_almost_eq(loud.z, 0.0, 0.001, "relief глушит L3")
	var mid := DirectorMath.ambience_mix(50.0, true)
	assert_lte(mid.y, 0.25)

func test_scare1_window() -> void:
	assert_false(DirectorMath.scare1_ready(false, 3, 80.0), "рано по этажу")
	assert_false(DirectorMath.scare1_ready(false, 7, 80.0), "поздно по этажу")
	assert_false(DirectorMath.scare1_ready(false, 5, 30.0), "мало Tension")
	assert_false(DirectorMath.scare1_ready(true, 5, 80.0), "уже отстрелян")
	assert_true(DirectorMath.scare1_ready(false, 5, 50.0))

func test_scare2_only_floor8_once() -> void:
	assert_false(DirectorMath.scare2_ready(false, 7))
	assert_true(DirectorMath.scare2_ready(false, 8))
	assert_false(DirectorMath.scare2_ready(true, 8))
