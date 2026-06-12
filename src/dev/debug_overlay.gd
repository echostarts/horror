class_name DebugOverlay
extends CanvasLayer
## Диагностика по F3: FPS, этаж, фаза, seed, Tension + график.
## Создаётся ТОЛЬКО из Main за проверкой OS.is_debug_build() — в release-экспорте
## оверлея нет (ARCHITECTURE.md, D-003).

const SAMPLE_INTERVAL: float = 0.1
const SAMPLE_COUNT: int = 300   # 30 секунд истории при шаге 0.1 c

class TensionGraph extends Control:
	var samples := PackedFloat32Array()
	var head: int = 0

	func _init() -> void:
		samples.resize(DebugOverlay.SAMPLE_COUNT)
		custom_minimum_size = Vector2(300.0, 80.0)

	func push_sample(value: float) -> void:
		samples[head] = value
		head = (head + 1) % samples.size()
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.55))
		var count := samples.size()
		var points := PackedVector2Array()
		points.resize(count)
		for i: int in count:
			var v := samples[(head + i) % count]
			points[i] = Vector2(size.x * float(i) / float(count - 1), size.y * (1.0 - v / 100.0))
		draw_polyline(points, Color(1.0, 0.45, 0.25), 1.0)

var _panel: VBoxContainer
var _info: Label
var _graph: TensionGraph
var _accum: float = 0.0
var _anomaly: String = "—"

func _init() -> void:
	layer = 100

func _ready() -> void:
	_panel = VBoxContainer.new()
	_panel.position = Vector2(8.0, 8.0)
	_panel.visible = false
	add_child(_panel)
	_info = Label.new()
	_info.add_theme_font_size_override(&"font_size", 13)
	_panel.add_child(_info)
	_graph = TensionGraph.new()
	_panel.add_child(_graph)
	EventBus.anomaly_spawned.connect(func(id: StringName) -> void: _anomaly = String(id))
	EventBus.anomaly_cleared.connect(func(_id: StringName) -> void: _anomaly = "—")

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug_overlay"):
		_panel.visible = not _panel.visible

func _process(delta: float) -> void:
	_accum += delta
	if _accum < SAMPLE_INTERVAL:
		return
	_accum = 0.0
	_graph.push_sample(Director.tension)
	if not _panel.visible:
		return
	_info.text = "FPS: %d (%.2f ms)\nЭтаж: %d | Фаза: %s | Серия: %d | Ошибки: %d\nSeed: %d\nTension: %.1f | Tier≤%d%s%s\nАномалия (Q): %s" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		GameState.current_floor,
		GameState.Phase.keys()[GameState.phase],
		GameState.correct_streak,
		GameState.mistakes,
		GameState.run_seed,
		Director.tension,
		Director.allowed_max_tier(),
		" | RELIEF" if Director.relief_active() else "",
		" | SILENCE" if Director.is_silence_active() else "",
		_anomaly,
	]
