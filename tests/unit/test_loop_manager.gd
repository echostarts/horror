extends GutTest
## Вердикты Loop Manager (BRIEF 3.1): таблица истинности, прогрессия этажей,
## сброс, финал.

func test_anomaly_down_advances() -> void:
	assert_eq(LoopManager.judge(true, LoopManager.DIR_DOWN), LoopManager.Verdict.ADVANCE)

func test_anomaly_up_resets() -> void:
	assert_eq(LoopManager.judge(true, LoopManager.DIR_UP), LoopManager.Verdict.RESET)

func test_clean_up_advances() -> void:
	assert_eq(LoopManager.judge(false, LoopManager.DIR_UP), LoopManager.Verdict.ADVANCE)

func test_clean_down_resets() -> void:
	assert_eq(LoopManager.judge(false, LoopManager.DIR_DOWN), LoopManager.Verdict.RESET)

func test_progression_to_top() -> void:
	var loop := LoopManager.new()
	var result: Dictionary = {}
	for i: int in 8:
		result = loop.commit(false, LoopManager.DIR_UP)
	assert_eq(int(result["floor"]), 9)
	assert_true(bool(result["finished"]))

func test_not_finished_before_top() -> void:
	var loop := LoopManager.new()
	for i: int in 7:
		var result := loop.commit(false, LoopManager.DIR_UP)
		assert_false(bool(result["finished"]), "финал раньше 9 этажа")

func test_wrong_call_resets_to_first() -> void:
	var loop := LoopManager.new()
	for i: int in 5:
		loop.commit(false, LoopManager.DIR_UP)
	var result := loop.commit(true, LoopManager.DIR_UP)
	assert_eq(result["verdict"], LoopManager.Verdict.RESET)
	assert_eq(int(result["floor"]), 1)
	assert_false(bool(result["finished"]))

func test_mixed_correct_calls_advance() -> void:
	var loop := LoopManager.new()
	loop.commit(false, LoopManager.DIR_UP)
	var result := loop.commit(true, LoopManager.DIR_DOWN)
	assert_eq(result["verdict"], LoopManager.Verdict.ADVANCE)
	assert_eq(int(result["floor"]), 3)
