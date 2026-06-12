extends Node
## Smoke-проверка M2 (env ETAZH9_SMOKE=1, headless): полный честный забег
## 1->9. Бот читает staged-вопрос через debug-API и телепортируется в верную
## сторону (аномалия -> вниз, чисто -> вверх), доходит до финала «Дом»,
## подходит к приоткрытой двери и ждёт run_ended. Это интеграционный тест
## DoD M2: «a full 1->9 run is playable start to finish».

var _commits: int = 0
var _ended: bool = false

func _ready() -> void:
	EventBus.verdict_resolved.connect(func(_c: bool, _f: int) -> void: _commits += 1)
	EventBus.run_ended.connect(func() -> void: _ended = true)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	var chain := get_tree().get_first_node_in_group(&"chain_manager") as ChainManager
	var landed := player.is_on_floor()
	var wrong_calls := 0
	for i: int in 30:
		if GameState.current_floor >= 9 or _ended:
			break
		if not await _wait_idle(chain):
			break
		var before := _commits
		var floor_before := GameState.current_floor
		var question := chain.debug_question_id()
		var has_anomaly := question != &""
		var target := chain.debug_module(-1 if has_anomaly else 1)
		player.global_position = target.landing_center_global() + Vector3(0.0, 0.2, 0.0)
		if not await _wait_commit(before):
			break
		if GameState.current_floor <= floor_before and GameState.current_floor == 1 \
				and floor_before >= 1:
			wrong_calls += 1
			print("SMOKE WRONG: floor=%d q='%s' dir=%s -> floor=%d" % [
				floor_before, question, "DOWN" if has_anomaly else "UP",
				GameState.current_floor])
	# Финал: дверь №36 приоткрыта на площадке уровня 0 — подходим к ней.
	await _wait_idle(chain)
	var finale_ok := false
	if GameState.current_floor >= 9:
		var module := chain.debug_module(0)
		player.global_position = module.to_global(Vector3(0.55,
			FlightModule.TOTAL_RISE + 0.2, FlightModule.MODULE_DEPTH - 0.5))
		for frame: int in 600:
			if _ended:
				finale_ok = true
				break
			await get_tree().process_frame
	print("SMOKE landed=%s commits=%d wrong=%d floor=%d tension=%.1f ended=%s" % [
		landed, _commits, wrong_calls, GameState.current_floor, Director.tension, _ended])
	var ok := landed and wrong_calls == 0 and GameState.current_floor >= 9 \
		and finale_ok and Director.tension > 40.0
	print("SMOKE RESULT: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

func _wait_idle(chain: ChainManager) -> bool:
	for frame: int in 600:
		if not chain.is_busy():
			return true
		await get_tree().process_frame
	push_error("SMOKE: ChainManager не освободился за 600 кадров")
	return false

func _wait_commit(before: int) -> bool:
	for frame: int in 600:
		if _commits > before:
			return true
		await get_tree().process_frame
	push_error("SMOKE: commit не случился за 600 кадров")
	return false
