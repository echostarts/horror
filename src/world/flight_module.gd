class_name FlightModule
extends Node3D
## Процедурный модуль «сегмента»: марш (полширины шахты) + этажная площадка
## с двумя дверями. Switchback-чейнинг: модуль уровня L+1 = модуль L * CHAIN_STEP
## (поворот на 180° + подъём). Канонические размеры — ARCHITECTURE.md.
##
## Контентные хуки для аномалий: set_step_count (через SegmentConfig),
## set_lamp_warm, set_graffiti, show_extra_shoes, set_wet_footprints,
## set_door_floor / reveal_stencil.

signal landing_entered(module: FlightModule)
signal flight_entered(module: FlightModule)

const TOTAL_RISE: float = 2.4
const TOTAL_RUN: float = 3.6
const LANDING_DEPTH: float = 1.5
const SHAFT_WIDTH: float = 2.2          # между внутренними плоскостями стен
const FLIGHT_WIDTH: float = 1.05
const FLIGHT_X: float = -0.575          # центр марша (паритет A)
const WALL_T: float = 0.1
const MODULE_DEPTH: float = TOTAL_RUN + LANDING_DEPTH  # 5.1

const COLD_LIGHT := Color(0.82, 0.9, 1.0)
const WARM_LIGHT := Color(1.0, 0.72, 0.45)

var cfg: SegmentConfig
var level: int = 0   # ступень тредмила; выставляет ChainManager

var _lamp_light: OmniLight3D
var _lamp_box: CSGBox3D
var _stencil: Label3D
var _door_labels: Array[Label3D] = []
var _graffiti: Label3D
var _shoes: Array[CSGBox3D] = []
var _footprints: Array[CSGBox3D] = []

## Поворот на 180° + сдвиг на этаж: transform модуля L+1 в кадре модуля L.
static func chain_step() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, TOTAL_RISE, MODULE_DEPTH))

func build(new_cfg: SegmentConfig) -> void:
	cfg = new_cfg
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_door_labels.clear()
	_shoes.clear()
	_footprints.clear()
	_build_geometry()
	_build_props()
	_build_areas()

# ---------------------------------------------------------------- геометрия

func _build_geometry() -> void:
	var wall_mat := _mat(&"wall")
	var floor_mat := _mat(&"floor")
	var step_mat := _mat(&"step")
	var eps := 0.002 * float(absi(level) % 2)  # паритетный сдвиг против z-fighting стен

	var rise := TOTAL_RISE / float(cfg.step_count)
	var run := TOTAL_RUN / float(cfg.step_count)
	for i: int in cfg.step_count:
		var h := rise * float(i + 1)
		_box("Step%d" % (i + 1), Vector3(FLIGHT_WIDTH, h, run),
			Vector3(FLIGHT_X, h * 0.5, run * (float(i) + 0.5)), step_mat, false)
	_add_ramp_like("StairRamp", 0.1, 0.0, true, null)          # коллизия капсулы (D-001)
	_add_ramp_like("FlightSoffit", 0.14, -0.3, true, wall_mat) # гладкая «подшивка» марша снизу

	_box("Landing", Vector3(SHAFT_WIDTH + 0.2, 0.1, LANDING_DEPTH + 0.06),
		Vector3(0.0, TOTAL_RISE - 0.05, TOTAL_RUN + LANDING_DEPTH * 0.5 + 0.03), floor_mat, true)

	# Боковые стены — полоса высотой ровно в этаж: соседние уровни стыкуются без нахлёста.
	for side: float in [-1.0, 1.0]:
		_box("Wall%s" % ("L" if side < 0.0 else "R"),
			Vector3(WALL_T, TOTAL_RISE, MODULE_DEPTH + 0.2),
			Vector3(side * (SHAFT_WIDTH * 0.5 + WALL_T * 0.5 + eps), TOTAL_RISE * 0.5, MODULE_DEPTH * 0.5),
			wall_mat, true)

	# Торцевая (дверная) стена своей площадки — полоса следующего этажа по высоте;
	# у соседних паритетов эти полосы тайлят противоположные торцы шахты.
	_box("DoorWall", Vector3(SHAFT_WIDTH + 0.2, TOTAL_RISE, WALL_T),
		Vector3(0.0, TOTAL_RISE * 1.5, MODULE_DEPTH + WALL_T * 0.5 + eps), wall_mat, true)

	# Перила вдоль открытой кромки марша (без прыжка капсула не перелезет 0.95 м).
	var rail_len := Vector2(TOTAL_RUN, TOTAL_RISE).length() + 0.2
	var rail := _box("Handrail", Vector3(0.05, 0.06, rail_len), Vector3.ZERO, _mat(&"rail"), true)
	var angle := atan2(TOTAL_RISE, TOTAL_RUN)
	rail.rotation.x = -angle
	var mid := Vector3(-0.075, TOTAL_RISE * 0.5 + 0.95, TOTAL_RUN * 0.5)
	rail.position = mid
	for i: int in 3:
		var t := 0.2 + 0.3 * float(i)
		_box("Baluster%d" % i, Vector3(0.04, 0.95, 0.04),
			Vector3(-0.075, TOTAL_RISE * t + 0.475, TOTAL_RUN * t), _mat(&"rail"), false)

func _add_ramp_like(node_name: String, thickness: float, normal_offset: float,
		collide: bool, mat: Material) -> void:
	var length := Vector2(TOTAL_RUN, TOTAL_RISE).length()
	var angle := atan2(TOTAL_RISE, TOTAL_RUN)
	var normal := Vector3(0.0, cos(angle), -sin(angle))
	var center := Vector3(FLIGHT_X, TOTAL_RISE * 0.5, TOTAL_RUN * 0.5) \
		+ normal * (normal_offset - thickness * 0.5)
	if mat == null:
		var body := StaticBody3D.new()
		body.name = node_name
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(FLIGHT_WIDTH, thickness, length)
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		body.rotation.x = -angle
		body.position = center
	else:
		var slab := _box(node_name, Vector3(FLIGHT_WIDTH, thickness, length), Vector3.ZERO, mat, collide)
		slab.rotation.x = -angle
		slab.position = center

# ------------------------------------------------------------------- пропсы

func _build_props() -> void:
	var door_mat := _mat(&"door")
	var landing_y := TOTAL_RISE
	var wall_z := MODULE_DEPTH  # внутренняя плоскость дверной стены

	var numbers := cfg.door_numbers()
	for i: int in 2:
		var x := -0.55 if i == 0 else 0.55
		_box("Door%d" % numbers[i], Vector3(0.9, 2.05, 0.08),
			Vector3(x, landing_y + 1.025, wall_z - 0.04), door_mat, true)
		var label := Label3D.new()
		label.name = "DoorNumber%d" % i
		label.font_size = 48
		label.pixel_size = 0.003
		label.modulate = Color(0.8, 0.76, 0.62)
		label.position = Vector3(x, landing_y + 2.22, wall_z - 0.06)
		label.rotation.y = PI
		label.text = str(numbers[i])
		add_child(label)
		_door_labels.append(label)

	_stencil = Label3D.new()
	_stencil.name = "FloorStencil"
	_stencil.font_size = 96
	_stencil.pixel_size = 0.004
	_stencil.modulate = Color(0.5, 0.16, 0.12)
	_stencil.position = Vector3(0.0, landing_y + 1.5, wall_z - 0.06)
	_stencil.rotation.y = PI
	_stencil.text = str(cfg.floor_label)
	_stencil.visible = false   # delayed verdict: открывается только при commit
	add_child(_stencil)

	# Почтовые ящики между дверями, под трафаретом.
	_box("Mailboxes", Vector3(0.55, 0.45, 0.12),
		Vector3(0.0, landing_y + 0.55, wall_z - 0.08), _mat(&"metal"), true)

	# Мусоропровод — компактно в углу площадки, вне дорожек между маршами.
	_box("TrashChute", Vector3(0.34, 2.25, 0.34),
		Vector3(0.9, landing_y + 1.125, TOTAL_RUN + 0.21), _mat(&"metal"), true)

	# Лампа площадки: холодный люминесцент под слабом модуля L+2.
	_lamp_box = _box("Lamp", Vector3(0.42, 0.05, 0.12),
		Vector3(0.0, landing_y + 2.27, TOTAL_RUN + LANDING_DEPTH * 0.5), null, false)
	_lamp_box.material = _make_lamp_material(COLD_LIGHT)
	_lamp_light = OmniLight3D.new()
	_lamp_light.name = "LampLight"
	_lamp_light.position = Vector3(0.0, landing_y + 2.0, TOTAL_RUN + LANDING_DEPTH * 0.5)
	_lamp_light.light_color = COLD_LIGHT
	_lamp_light.light_energy = 1.15
	_lamp_light.omni_range = 8.0
	_lamp_light.shadow_enabled = true
	add_child(_lamp_light)

	# Окно (ночь) над маршем, правая стена.
	_box("Window", Vector3(0.06, 1.1, 0.85),
		Vector3(SHAFT_WIDTH * 0.5 - 0.01, TOTAL_RISE * 0.5 + 1.45, TOTAL_RUN * 0.45),
		_mat(&"window"), false)

	# Граффити на стене вдоль марша (базовый текст — константа дома; D1 меняет).
	_graffiti = Label3D.new()
	_graffiti.name = "Graffiti"
	_graffiti.font_size = 40
	_graffiti.pixel_size = 0.0035
	_graffiti.modulate = Color(0.32, 0.34, 0.38)
	_graffiti.position = Vector3(-(SHAFT_WIDTH * 0.5) + 0.02, TOTAL_RISE * 0.5 + 0.55, TOTAL_RUN * 0.5)
	_graffiti.rotation.y = PI * 0.5
	_graffiti.text = "ЦОЙ ЖИВ"
	add_child(_graffiti)

	# Скрытые носители аномалий: обувь у правой двери (A1)…
	for i: int in 2:
		var shoe := _box("Shoe%d" % i, Vector3(0.1, 0.075, 0.27),
			Vector3(0.34 + 0.14 * float(i), landing_y + 0.0375, wall_z - 0.26),
			_mat(&"shoe"), false)
		shoe.rotation.y = 0.15 - 0.3 * float(i)
		shoe.visible = false
		_shoes.append(shoe)

	# …и мокрые следы на ступенях, «спускающиеся» вниз (E3).
	var rise := TOTAL_RISE / float(cfg.step_count)
	var run := TOTAL_RUN / float(cfg.step_count)
	for i: int in range(0, cfg.step_count, 2):
		var foot := _box("Footprint%d" % i, Vector3(0.085, 0.004, 0.23),
			Vector3(FLIGHT_X + (0.11 if (i / 2) % 2 == 0 else -0.11),
				rise * float(i + 1) + 0.004, run * (float(i) + 0.5)),
			_mat(&"wet"), false)
		foot.visible = false
		_footprints.append(foot)

func _build_areas() -> void:
	var landing_area := _area("LandingArea",
		Vector3(SHAFT_WIDTH, 1.8, LANDING_DEPTH - 0.1),
		Vector3(0.0, TOTAL_RISE + 1.0, TOTAL_RUN + LANDING_DEPTH * 0.5))
	landing_area.body_entered.connect(_on_landing_body.bind())
	var flight_area := _area("FlightArea",
		Vector3(FLIGHT_WIDTH, 2.0, 0.6),
		Vector3(FLIGHT_X, TOTAL_RISE * 0.5 + 1.0, TOTAL_RUN * 0.5))
	flight_area.body_entered.connect(_on_flight_body.bind())

func _on_landing_body(body: Node3D) -> void:
	if body is Player:
		landing_entered.emit(self)

func _on_flight_body(body: Node3D) -> void:
	if body is Player:
		flight_entered.emit(self)

# ------------------------------------------------------- хуки контента/аномалий

func set_door_floor(floor_label: int) -> void:
	cfg.floor_label = floor_label
	var numbers := cfg.door_numbers()
	for i: int in 2:
		_door_labels[i].text = str(numbers[i])
	_stencil.text = str(floor_label)

func reveal_stencil(floor_label: int) -> void:
	_stencil.text = str(floor_label)
	_stencil.visible = true

func hide_stencil() -> void:
	_stencil.visible = false

func set_lamp_warm() -> void:
	_lamp_light.light_color = WARM_LIGHT
	_lamp_box.material = _make_lamp_material(WARM_LIGHT)

func set_graffiti(text: String) -> void:
	_graffiti.text = text

func show_extra_shoes() -> void:
	for shoe: CSGBox3D in _shoes:
		shoe.visible = true

func set_wet_footprints(enabled: bool) -> void:
	for foot: CSGBox3D in _footprints:
		foot.visible = enabled

func landing_center_global() -> Vector3:
	return to_global(Vector3(0.0, TOTAL_RISE + 0.05, TOTAL_RUN + LANDING_DEPTH * 0.5))

# ------------------------------------------------------------------ утилиты

static var _materials: Dictionary = {}

static func _mat(key: StringName) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.roughness = 0.95
	match key:
		&"wall": m.albedo_color = Color(0.26, 0.29, 0.26)
		&"floor": m.albedo_color = Color(0.31, 0.31, 0.32)
		&"step": m.albedo_color = Color(0.36, 0.36, 0.37)
		&"door": m.albedo_color = Color(0.26, 0.18, 0.13)
		&"rail": m.albedo_color = Color(0.16, 0.2, 0.16)
		&"metal": m.albedo_color = Color(0.22, 0.24, 0.27)
		&"shoe": m.albedo_color = Color(0.16, 0.12, 0.1)
		&"wet":
			m.albedo_color = Color(0.05, 0.06, 0.08)
			m.roughness = 0.2
			m.metallic = 0.15
		&"window":
			m.albedo_color = Color(0.05, 0.07, 0.11)
			m.emission_enabled = true
			m.emission = Color(0.1, 0.14, 0.22)
			m.emission_energy_multiplier = 1.2
	_materials[key] = m
	return m

func _make_lamp_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.5)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.4
	m.roughness = 0.9
	return m

func _box(box_name: String, size: Vector3, pos: Vector3, mat: Material, collide: bool) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = pos
	if mat != null:
		box.material = mat
	box.use_collision = collide
	add_child(box)
	return box

func _area(area_name: String, size: Vector3, pos: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = area_name
	area.collision_layer = 0
	area.collision_mask = 2   # слой игрока
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	area.position = pos
	add_child(area)
	return area
