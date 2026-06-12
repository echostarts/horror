extends Node
## Оболочка: low-res SubViewport-пайплайн, захват мыши, оверлеи (переходы,
## субтитры, debug). Мышиный look обрабатывается ЗДЕСЬ (корневой viewport)
## и пробрасывается в Player.apply_look (ARCHITECTURE.md, D-002).

@onready var _container: SubViewportContainer = $GameViewportContainer
@onready var _viewport: SubViewport = $GameViewportContainer/GameViewport
@onready var _player: Player = $GameViewportContainer/GameViewport/World/Player

func _ready() -> void:
	get_window().size_changed.connect(_fit_viewport_to_window)
	EventBus.setting_changed.connect(_on_setting_changed)
	_apply_internal_resolution()
	add_child(TransitionLayer.new())
	add_child(Subtitles.new())
	if OS.is_debug_build():
		add_child(DebugOverlay.new())
	if OS.get_environment("ETAZH9_SMOKE") == "1":
		add_child(preload("res://src/dev/smoke_check.gd").new())
	if not OS.get_environment("ETAZH9_SHOT").is_empty():
		add_child(preload("res://src/dev/shot_check.gd").new())
	var forced_seed := 0
	var seed_env := OS.get_environment("ETAZH9_SEED")
	if not seed_env.is_empty():
		forced_seed = int(seed_env)
	GameState.start_run(forced_seed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_player.apply_look((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed(&"pause"):
		_toggle_mouse_capture()

func _toggle_mouse_capture() -> void:
	# TODO(M2+): заменить на полноценную паузу/меню (BRIEF Section 9).
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if key == &"video/internal_height":
		_apply_internal_resolution()

func _apply_internal_resolution() -> void:
	var height: int = SettingsService.get_int(&"video/internal_height")
	_viewport.size = Vector2i((height * 16) / 9, height)
	_fit_viewport_to_window()

## Целочисленного масштаба не требуем: nearest-neighbor при любом скейле
## даёт нужную «жирную» пиксельность; при несовпадении аспекта — леттербокс.
func _fit_viewport_to_window() -> void:
	var win := Vector2(get_window().size)
	var internal := Vector2(_viewport.size)
	var scale_factor := minf(win.x / internal.x, win.y / internal.y)
	_container.size = internal
	_container.scale = Vector2(scale_factor, scale_factor)
	_container.position = (win - internal * scale_factor) * 0.5
