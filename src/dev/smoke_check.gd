extends Node
## Smoke-проверка M1 (env ETAZH9_SMOKE=1, headless): телепорт-коммиты лупа.
## Игрока 6 раз переносит на площадку уровня +1: каждый перенос обязан дать
## commit (advance ИЛИ reset — оба легальны), re-anchor обязан удерживать
## мир у origin. Сами вердикты покрыты GUT-тестами LoopManager.

var _commits: int = 0

func _ready() -> void:
	EventBus.verdict_resolved.connect(func(_c: bool, _f: int) -> void: _commits += 1)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	var chain := get_tree().get_first_node_in_group(&"chain_manager") as ChainManager
	var landed := player.is_on_floor()
	for i: int in 6:
		if not await _wait_idle(chain):
			break
		var before := _commits
		var target := chain.debug_module(1)
		player.global_position = target.landing_center_global() + Vector3(0.0, 0.2, 0.0)
		if not await _wait_commit(before):
			break
	var y_bounded := absf(player.global_position.y) < 8.0
	print("SMOKE landed=%s commits=%d y=%.2f floor=%d tension=%.1f" % [
		landed, _commits, player.global_position.y, GameState.current_floor, Director.tension])
	var ok := landed and _commits == 6 and y_bounded
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
