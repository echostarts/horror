class_name TransitionLayer
extends CanvasLayer
## VHS-переходы (M1-заглушки, шейдерный стек придёт в M3):
## glitch() — микро-сбой трекинга на commit (маскирует рестейдж мира),
## rewind_in/out() — «перемотка» на reset, show_ending() — финальная карточка.
## Живёт в группе "transition_layer"; ChainManager await'ит его методы.

enum Mode { NONE, GLITCH, REWIND, ENDING }

const BAR_COUNT: int = 7

var _mode: Mode = Mode.NONE
var _glitch_left: float = 0.0
var _cover: ColorRect
var _bars: Array[ColorRect] = []
var _title: Label
var _subtitle: Label
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	layer = 90

func _ready() -> void:
	add_to_group(&"transition_layer")
	_cover = ColorRect.new()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.color = Color.BLACK
	_cover.visible = false
	add_child(_cover)
	for i: int in BAR_COUNT:
		var bar := ColorRect.new()
		bar.visible = false
		_cover.add_child(bar)
		_bars.append(bar)
	_title = _make_label(64, Vector2(0.0, -60.0))
	_subtitle = _make_label(18, Vector2(0.0, 30.0))

func _make_label(font_size: int, offset: Vector2) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position += offset
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", Color(0.78, 0.8, 0.84))
	label.visible = false
	_cover.add_child(label)
	return label

## Мгновенный сбой трекинга: следующий кадр(ы) закрыты шумом — рестейдж невидим.
func glitch(duration: float) -> void:
	if _mode == Mode.ENDING:
		return
	_mode = Mode.GLITCH
	_glitch_left = duration
	_cover.visible = true
	AudioDirector.play_ui(&"PLACEHOLDER_glitch")

func rewind_in() -> void:
	if _mode == Mode.ENDING:
		return
	_mode = Mode.REWIND
	_cover.visible = true
	_title.text = "◀◀"
	_title.visible = true
	AudioDirector.play_ui(&"PLACEHOLDER_rewind")
	await get_tree().create_timer(0.45).timeout

func rewind_out() -> void:
	await get_tree().create_timer(0.65).timeout
	if _mode == Mode.REWIND:
		_hide_all()

func show_ending() -> void:
	_mode = Mode.ENDING
	_cover.visible = true
	_cover.color = Color.BLACK
	for bar: ColorRect in _bars:
		bar.visible = false
	_title.text = "ЭТАЖ 9"
	_title.visible = true
	_subtitle.text = "конец среза M1 — Enter: подняться снова"
	_subtitle.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if _mode == Mode.ENDING and event.is_action_pressed(&"ui_accept"):
		_mode = Mode.NONE
		_hide_all()
		get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if _mode == Mode.GLITCH:
		_glitch_left -= delta
		if _glitch_left <= 0.0:
			_hide_all()
			return
		_scramble(0.55)
	elif _mode == Mode.REWIND:
		_scramble(0.9)

func _scramble(darkness: float) -> void:
	var g := _rng.randf_range(0.04, 0.22)
	_cover.color = Color(g, g, g * 1.1, darkness if _mode == Mode.GLITCH else 1.0)
	var size := _cover.size
	for bar: ColorRect in _bars:
		bar.visible = true
		var bg := _rng.randf_range(0.0, 0.45)
		bar.color = Color(bg, bg, bg * 1.15)
		bar.position = Vector2(0.0, _rng.randf() * size.y)
		bar.size = Vector2(size.x, _rng.randf_range(2.0, 18.0))

func _hide_all() -> void:
	_mode = Mode.NONE
	_cover.visible = false
	_title.visible = false
	_subtitle.visible = false
	for bar: ColorRect in _bars:
		bar.visible = false
	_cover.color = Color.BLACK
