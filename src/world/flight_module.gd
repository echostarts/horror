class_name FlightModule
extends Node3D
## Процедурный модуль «сегмента»: марш (полширины шахты) + этажная площадка
## с двумя дверями. Switchback-чейнинг: модуль уровня L+1 = модуль L * CHAIN_STEP
## (поворот на 180° + подъём). Канонические размеры — ARCHITECTURE.md.
##
## Контентные хуки аномалий (Appendix A): ступени через SegmentConfig (B1),
## лампа (C1/C2), граффити (D1), обувь (A1), следы (E3), ящики (A2),
## велосипед (A3), потолок (B2), дубль двери (B3), свет из-под двери (C3),
## зеркальный трафарет (D2), глазок (E1), силуэт (E2). reset_landing_props()
## возвращает площадку к базе без пересборки (игрок может на ней стоять).
## _process включается только при активных анимациях (zero-cost база).

signal landing_entered(module: FlightModule)
signal flight_entered(module: FlightModule)
signal ending_door_reached

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
const LAMP_ENERGY: float = 1.15
const GAZE_DEPART_TIME: float = 0.4     # BRIEF 3.4: взгляд >0.4 c -> силуэт уходит

var cfg: SegmentConfig
var level: int = 0   # ступень тредмила; выставляет ChainManager

var _lamp_light: OmniLight3D
var _lamp_box: CSGBox3D
var _stencil: Label3D
var _stencil_spot: SpotLight3D
var _stencil_tween: Tween
var _door_labels: Array[Label3D] = []
var _doors: Array[CSGBox3D] = []
var _graffiti: Label3D
var _shoes: Array[CSGBox3D] = []
var _footprints: Array[CSGBox3D] = []
var _mail_overflow: Array[Node3D] = []
var _bike_parts: Array[Node3D] = []
var _lock: CSGBox3D
var _low_ceiling: CSGBox3D
var _peepholes: Array[CSGCylinder3D] = []
var _glow_strip: CSGBox3D
var _glow_light: OmniLight3D
var _glow_mat: StandardMaterial3D
var _silhouette: MeshInstance3D
var _silhouette_mat: StandardMaterial3D

# Состояние анимаций (сбрасывается build()):
var _anim_time: float = 0.0
var _flicker_on: bool = false
var _glow_door: int = -1
var _watcher_door: int = -1
var _watcher_dark: bool = false
var _silhouette_on: bool = false
var _silhouette_leaving: bool = false
var _gaze_accum: float = 0.0
var _close_flash_left: float = 0.0
var _ending_armed: bool = false
var _player_ref: Node3D

## Поворот на 180° + сдвиг на этаж: transform модуля L+1 в кадре модуля L.
static func chain_step() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, TOTAL_RISE, MODULE_DEPTH))

func build(new_cfg: SegmentConfig) -> void:
	cfg = new_cfg
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_door_labels.clear()
	_doors.clear()
	_shoes.clear()
	_footprints.clear()
	_mail_overflow.clear()
	_bike_parts.clear()
	_peepholes.clear()
	_anim_time = 0.0
	_flicker_on = false
	_glow_door = -1
	_watcher_door = -1
	_watcher_dark = false
	_silhouette_on = false
	_silhouette_leaving = false
	_gaze_accum = 0.0
	_close_flash_left = 0.0
	_ending_armed = false
	set_process(false)
	_build_geometry()
	_build_props()
	_build_anomaly_carriers()
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
	# Укорочены и сдвинуты вверх по маршу: нижний хвост НЕ нависает над
	# площадкой предыдущего модуля (там он опускался ниже головы и толкался).
	var diag := Vector2(TOTAL_RUN, TOTAL_RISE).length()
	var rail_len := diag - 0.35
	var rail := _box("Handrail", Vector3(0.05, 0.06, rail_len), Vector3.ZERO, _mat(&"rail"), true)
	var angle := atan2(TOTAL_RISE, TOTAL_RUN)
	rail.rotation.x = -angle
	var along := Vector3(0.0, TOTAL_RISE, TOTAL_RUN) / diag * 0.175
	rail.position = Vector3(-0.075, TOTAL_RISE * 0.5 + 0.95, TOTAL_RUN * 0.5) + along
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
		var door := _box("Door%d" % i, Vector3(0.9, 2.05, 0.08),
			Vector3(x, landing_y + 1.025, wall_z - 0.04), door_mat, true)
		_doors.append(door)
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
		# Глазок (E1): тёмный «зрачок» со стеклянным бликом.
		var peep := CSGCylinder3D.new()
		peep.name = "Peephole%d" % i
		peep.radius = 0.02
		peep.height = 0.03
		peep.material = _mat(&"peep")
		peep.rotation.x = PI * 0.5
		peep.position = Vector3(x, landing_y + 1.5, wall_z - 0.09)
		add_child(peep)
		_peepholes.append(peep)

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

	# Подсветка reveal'а (Section 8: «staged with light + piano-wire note»):
	# узкий луч на трафарет, разжигается при коммите.
	_stencil_spot = SpotLight3D.new()
	_stencil_spot.name = "StencilSpot"
	_stencil_spot.light_color = Color(0.95, 0.9, 0.78)
	_stencil_spot.light_energy = 0.0
	_stencil_spot.spot_range = 2.6
	_stencil_spot.spot_angle = 24.0
	_stencil_spot.position = Vector3(0.0, landing_y + 2.25, wall_z - 0.75)
	add_child(_stencil_spot)

	# Почтовые ящики между дверями, под трафаретом.
	_box("Mailboxes", Vector3(0.55, 0.45, 0.12),
		Vector3(0.0, landing_y + 0.55, wall_z - 0.08), _mat(&"metal"), true)

	# Мусоропровод — компактно в углу площадки, вне дорожек между маршами.
	_box("TrashChute", Vector3(0.34, 2.25, 0.34),
		Vector3(0.9, landing_y + 1.125, TOTAL_RUN + 0.21), _mat(&"metal"), true)

	# Стояк отопления в углу у левой стены (база; к нему A3 пристёгивает замок).
	var pipe := CSGCylinder3D.new()
	pipe.name = "Riser"
	pipe.radius = 0.035
	pipe.height = TOTAL_RISE - 0.1
	pipe.material = _mat(&"metal")
	pipe.position = Vector3(-1.02, landing_y + TOTAL_RISE * 0.5 - 0.05, wall_z - 0.12)
	add_child(pipe)

	# Велосипед у левой стены площадки (база каждой площадки — дом повторяется;
	# A3 прячет велосипед, замок остаётся на стояке).
	_build_bike(landing_y)

	# Лампа площадки: холодный люминесцент под слабом модуля L+2.
	_lamp_box = _box("Lamp", Vector3(0.42, 0.05, 0.12),
		Vector3(0.0, landing_y + 2.27, TOTAL_RUN + LANDING_DEPTH * 0.5), null, false)
	_lamp_box.material = _make_lamp_material(COLD_LIGHT)
	_lamp_light = OmniLight3D.new()
	_lamp_light.name = "LampLight"
	_lamp_light.position = Vector3(0.0, landing_y + 2.0, TOTAL_RUN + LANDING_DEPTH * 0.5)
	_lamp_light.light_color = COLD_LIGHT
	_lamp_light.light_energy = LAMP_ENERGY
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

func _build_bike(landing_y: float) -> void:
	var bike_mat := _mat(&"bike")
	for wheel_z: float in [4.05, 4.9]:
		var wheel := CSGCylinder3D.new()
		wheel.name = "BikeWheel%d" % int(wheel_z * 10.0)
		wheel.radius = 0.3
		wheel.height = 0.045
		wheel.material = bike_mat
		wheel.rotation.z = PI * 0.5
		wheel.position = Vector3(-0.88, landing_y + 0.3, wheel_z)
		add_child(wheel)
		_bike_parts.append(wheel)
	var frame := _box("BikeFrame", Vector3(0.035, 0.035, 0.62),
		Vector3(-0.88, landing_y + 0.58, 4.48), bike_mat, false)
	frame.rotation.x = 0.12
	_bike_parts.append(frame)
	var seat_post := _box("BikeSeatPost", Vector3(0.03, 0.32, 0.03),
		Vector3(-0.88, landing_y + 0.72, 4.18), bike_mat, false)
	_bike_parts.append(seat_post)
	_bike_parts.append(_box("BikeSeat", Vector3(0.07, 0.03, 0.2),
		Vector3(-0.88, landing_y + 0.9, 4.18), bike_mat, false))
	var fork := _box("BikeFork", Vector3(0.03, 0.42, 0.03),
		Vector3(-0.88, landing_y + 0.62, 4.88), bike_mat, false)
	_bike_parts.append(fork)
	_bike_parts.append(_box("BikeBar", Vector3(0.3, 0.03, 0.03),
		Vector3(-0.81, landing_y + 0.86, 4.88), bike_mat, false))
	# Замок: база — висит на заднем колесе.
	_lock = _box("BikeLock", Vector3(0.15, 0.1, 0.05),
		Vector3(-0.84, landing_y + 0.16, 4.05), _mat(&"lock"), false)

## Скрытые носители аномалий: создаются при сборке, включаются хуками.
func _build_anomaly_carriers() -> void:
	var landing_y := TOTAL_RISE
	var wall_z := MODULE_DEPTH

	# A1: лишняя пара обуви у правой двери.
	for i: int in 2:
		var shoe := _box("Shoe%d" % i, Vector3(0.1, 0.075, 0.27),
			Vector3(0.34 + 0.14 * float(i), landing_y + 0.0375, wall_z - 0.26),
			_mat(&"shoe"), false)
		shoe.rotation.y = 0.15 - 0.3 * float(i)
		shoe.visible = false
		_shoes.append(shoe)

	# E3: мокрые следы на ступенях, «спускающиеся» вниз.
	var rise := TOTAL_RISE / float(cfg.step_count)
	var run := TOTAL_RUN / float(cfg.step_count)
	for i: int in range(0, cfg.step_count, 2):
		var foot := _box("Footprint%d" % i, Vector3(0.085, 0.004, 0.23),
			Vector3(FLIGHT_X + (0.11 if (i / 2) % 2 == 0 else -0.11),
				rise * float(i + 1) + 0.004, run * (float(i) + 0.5)),
			_mat(&"wet"), false)
		foot.visible = false
		_footprints.append(foot)

	# A2: ящик открыт и переполнен одинаковыми письмами.
	var flap := _box("MailFlap", Vector3(0.17, 0.13, 0.015),
		Vector3(-0.12, landing_y + 0.42, wall_z - 0.16), _mat(&"metal"), false)
	flap.rotation.x = -1.0
	flap.visible = false
	_mail_overflow.append(flap)
	for i: int in 5:
		var letter := _box("Letter%d" % i, Vector3(0.16, 0.012, 0.11),
			Vector3(-0.12 + 0.05 * float(i % 3) - 0.05,
				(landing_y + 0.36 - 0.02 * float(i)) if i < 2 else landing_y + 0.012,
				wall_z - 0.2 - 0.09 * float(maxi(i - 1, 0))),
			_mat(&"paper"), false)
		letter.rotation.y = 0.4 * float(i % 3) - 0.4
		if i < 2:
			letter.rotation.x = -0.5
		letter.visible = false
		_mail_overflow.append(letter)

	# B2: фальшпотолок на ~15% ниже (лампа опускается вместе с ним).
	_low_ceiling = _box("LowCeiling", Vector3(SHAFT_WIDTH, 0.1, LANDING_DEPTH + 0.04),
		Vector3(0.0, landing_y + 1.95 + 0.05, TOTAL_RUN + LANDING_DEPTH * 0.5),
		_mat(&"wall"), false)
	_low_ceiling.visible = false

	# C3: свет пульсирует из-под левой двери.
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.4, 0.33, 0.2)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(1.0, 0.85, 0.55)
	_glow_mat.emission_energy_multiplier = 0.0
	_glow_strip = _box("DoorGlow", Vector3(0.86, 0.02, 0.05),
		Vector3(-0.55, landing_y + 0.015, wall_z - 0.1), _glow_mat, false)
	_glow_strip.visible = false
	_glow_light = OmniLight3D.new()
	_glow_light.name = "DoorGlowLight"
	_glow_light.light_color = Color(1.0, 0.85, 0.55)
	_glow_light.light_energy = 0.0
	_glow_light.omni_range = 1.8
	_glow_light.position = Vector3(-0.55, landing_y + 0.1, wall_z - 0.4)
	add_child(_glow_light)

	# E2: силуэт на площадке (виден с марша снизу — «пролётом выше»).
	_silhouette_mat = StandardMaterial3D.new()
	_silhouette_mat.albedo_color = Color(0.015, 0.015, 0.02, 0.97)
	_silhouette_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_silhouette_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_silhouette_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 1.76)
	_silhouette = MeshInstance3D.new()
	_silhouette.name = "Silhouette"
	_silhouette.mesh = quad
	_silhouette.material_override = _silhouette_mat
	# Перед освещённой дверной стеной своей площадки: с марша снизу читается
	# чёрным контуром против света.
	_silhouette.position = Vector3(FLIGHT_X, TOTAL_RISE + 0.9, TOTAL_RUN + 0.72)
	_silhouette.visible = false
	add_child(_silhouette)

func _build_areas() -> void:
	var landing_area := _area("LandingArea",
		Vector3(SHAFT_WIDTH, 1.8, LANDING_DEPTH - 0.1),
		Vector3(0.0, TOTAL_RISE + 1.0, TOTAL_RUN + LANDING_DEPTH * 0.5))
	landing_area.body_entered.connect(_on_landing_body)
	var flight_area := _area("FlightArea",
		Vector3(FLIGHT_WIDTH, 2.0, 0.6),
		Vector3(FLIGHT_X, TOTAL_RISE * 0.5 + 1.0, TOTAL_RUN * 0.5))
	flight_area.body_entered.connect(_on_flight_body)

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
	_stencil_spot.look_at(_stencil.global_position)
	if _stencil_tween != null and _stencil_tween.is_running():
		_stencil_tween.kill()
	_stencil_spot.light_energy = 0.0
	_stencil_tween = create_tween()
	_stencil_tween.tween_property(_stencil_spot, "light_energy", 1.1, 0.45) \
		.set_trans(Tween.TRANS_SINE)

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

## A2: ящик открыт, одинаковые письма торчат и рассыпаны.
func show_mailbox_overflow() -> void:
	for node: Node3D in _mail_overflow:
		node.visible = true

## A3: велосипед исчез — закрытый замок остался на стояке.
func set_bike_missing() -> void:
	for part: Node3D in _bike_parts:
		part.visible = false
	_lock.position = Vector3(-0.95, TOTAL_RISE + 0.55, MODULE_DEPTH - 0.12)

## B2: потолок площадки ниже на ~15%.
func set_low_ceiling() -> void:
	_low_ceiling.visible = true
	_lamp_box.position.y = TOTAL_RISE + 1.83
	_lamp_light.position.y = TOTAL_RISE + 1.7

## B3: дверь заменена дублем №36 (правая).
func set_door_label_override(door_index: int, text: String) -> void:
	_door_labels[door_index].text = text

## C2: мерцание лампы в ритме сердцебиения.
func set_lamp_flicker_heartbeat() -> void:
	_flicker_on = true
	set_process(true)

## C3: тёплый свет пульсирует из-под двери.
func set_door_glow(_door_index: int) -> void:
	_glow_door = _door_index
	_glow_strip.visible = true
	set_process(true)

## D2: трафарет этажа зеркальный.
func set_stencil_mirrored() -> void:
	_stencil.scale.x = -1.0

## E1: глазок двери темнеет, когда проходишь мимо.
func set_peephole_watcher(door_index: int) -> void:
	_watcher_door = door_index
	set_process(true)

## E2: силуэт пролётом выше, уходит под взглядом.
func set_silhouette() -> void:
	_silhouette_on = true
	_silhouette_mat.albedo_color.a = 0.97
	_silhouette.visible = true
	set_process(true)

## Скер-слот 1: силуэт ближе, чем позволяет физика, — на мгновение.
func flash_silhouette_close(duration: float) -> void:
	_silhouette.position = Vector3(FLIGHT_X, TOTAL_RISE * 0.62 + 0.9, TOTAL_RUN * 0.62)
	_silhouette_mat.albedo_color.a = 1.0
	_silhouette.visible = true
	_close_flash_left = duration
	set_process(true)

## Возврат площадки к базе БЕЗ пересборки (игрок может стоять на ней).
func reset_landing_props() -> void:
	_lamp_light.light_color = COLD_LIGHT
	_lamp_light.light_energy = LAMP_ENERGY
	_lamp_light.visible = true
	_lamp_box.material = _make_lamp_material(COLD_LIGHT)
	_lamp_box.position.y = TOTAL_RISE + 2.27
	_lamp_light.position.y = TOTAL_RISE + 2.0
	_flicker_on = false
	for shoe: CSGBox3D in _shoes:
		shoe.visible = false
	for node: Node3D in _mail_overflow:
		node.visible = false
	for part: Node3D in _bike_parts:
		part.visible = true
	_lock.position = Vector3(-0.84, TOTAL_RISE + 0.16, 4.05)
	_low_ceiling.visible = false
	_glow_door = -1
	_glow_strip.visible = false
	_glow_light.light_energy = 0.0
	_stencil.scale.x = 1.0
	_watcher_door = -1
	_watcher_dark = false
	for peep: CSGCylinder3D in _peepholes:
		peep.material = _mat(&"peep")

## Гаснущая лампа (скер-слот 2 и финал «Дом»).
func lamp_off() -> void:
	_flicker_on = false
	_lamp_light.visible = false
	_lamp_box.material = _mat(&"lamp_dead")

func lamp_position_global() -> Vector3:
	return _lamp_light.global_position

## Финал: дверь №36 приоткрыта, за ней тёмная прихожая (BRIEF 3.5, скелет M2).
func set_door_ajar(door_index: int) -> void:
	var landing_y := TOTAL_RISE
	var wall_z := MODULE_DEPTH
	var door := _doors[door_index]
	var x := door.position.x
	door.visible = false
	door.use_collision = false
	# Проём в дверной стене.
	var doorway := CSGBox3D.new()
	doorway.name = "Doorway"
	doorway.size = Vector3(0.92, 2.06, 0.4)
	var wall := get_node("DoorWall") as CSGBox3D
	doorway.position = wall.to_local(to_global(Vector3(x, landing_y + 1.03, wall_z + WALL_T * 0.5)))
	doorway.operation = CSGShape3D.OPERATION_SUBTRACTION
	wall.add_child(doorway)
	# Полотно на петле, приоткрыто внутрь.
	var hinge := Node3D.new()
	hinge.name = "AjarHinge"
	hinge.position = Vector3(x + 0.45, landing_y + 1.025, wall_z + 0.02)
	add_child(hinge)
	var leaf := CSGBox3D.new()
	leaf.name = "AjarDoor"
	leaf.size = Vector3(0.9, 2.05, 0.08)
	leaf.material = _mat(&"door")
	leaf.use_collision = true
	leaf.position = Vector3(-0.45, 0.0, 0.0)
	hinge.add_child(leaf)
	hinge.rotation.y = 0.42
	# «Прихожая»: тёмный объём + едва тёплый свет из глубины.
	var hall := _box("Hallway", Vector3(1.1, 2.2, 1.6),
		Vector3(x, landing_y + 1.05, wall_z + WALL_T + 0.85), _mat(&"void"), false)
	hall.use_collision = false
	var glow := OmniLight3D.new()
	glow.name = "HallGlow"
	glow.light_color = Color(1.0, 0.82, 0.55)
	glow.light_energy = 0.35
	glow.omni_range = 1.6
	glow.position = Vector3(x, landing_y + 1.1, wall_z + 0.9)
	add_child(glow)
	# Триггер подхода к двери.
	var trigger := _area("EndingDoorArea", Vector3(1.2, 2.0, 1.0),
		Vector3(x, landing_y + 1.0, wall_z - 0.55))
	trigger.body_entered.connect(_on_ending_door_body)

func _on_ending_door_body(body: Node3D) -> void:
	if body is Player and not _ending_armed:
		_ending_armed = true
		ending_door_reached.emit()

func landing_center_global() -> Vector3:
	return to_global(Vector3(0.0, TOTAL_RISE + 0.05, TOTAL_RUN + LANDING_DEPTH * 0.5))

# ------------------------------------------------------------------ анимации

func _process(delta: float) -> void:
	_anim_time += delta
	var any_active := false
	if _flicker_on:
		any_active = true
		var tm := fmod(_anim_time, 0.95)   # «луб-дуб» ~63 уд/мин
		var dip := 0.5 * exp(-pow((tm - 0.08) / 0.045, 2.0)) \
			+ 0.35 * exp(-pow((tm - 0.32) / 0.05, 2.0))
		_lamp_light.light_energy = LAMP_ENERGY * (1.0 - dip)
	if _glow_door >= 0:
		any_active = true
		var pulse := 0.45 + 0.4 * sin(_anim_time * 2.0)   # медленная пульсация, не строб
		_glow_light.light_energy = pulse
		_glow_mat.emission_energy_multiplier = pulse * 2.2
	if _watcher_door >= 0 and not _watcher_dark:
		any_active = true
		_update_peephole_watcher()
	if _silhouette_on:
		any_active = true
		_update_silhouette_gaze(delta)
	if _silhouette_leaving:
		any_active = true
		_silhouette_mat.albedo_color.a -= delta * 2.8
		_silhouette.position.z += delta * 2.4
		if _silhouette_mat.albedo_color.a <= 0.0:
			_silhouette.visible = false
			_silhouette_leaving = false
	if _close_flash_left > 0.0:
		any_active = true
		_close_flash_left -= delta
		if _close_flash_left <= 0.0:
			_silhouette.visible = false
	if not any_active:
		set_process(false)

func _update_peephole_watcher() -> void:
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player_ref == null:
			return
	var peep := _peepholes[_watcher_door]
	if _player_ref.global_position.distance_to(peep.global_position) < 1.45:
		_watcher_dark = true
		peep.material = _mat(&"peep_dark")

func _update_silhouette_gaze(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var to_sil := _silhouette.global_position - camera.global_position
	if to_sil.length() > 14.0:
		return
	var forward := -camera.global_basis.z
	if forward.dot(to_sil.normalized()) > 0.978:   # ~12° от центра взгляда
		_gaze_accum += delta
		if _gaze_accum >= GAZE_DEPART_TIME:
			_silhouette_on = false
			_silhouette_leaving = true
			AudioDirector.play_event(&"PLACEHOLDER_footstep_concrete",
				_silhouette.global_position, AudioDirector.BUS_SFX)

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
		&"paper": m.albedo_color = Color(0.72, 0.7, 0.62)
		&"bike": m.albedo_color = Color(0.2, 0.16, 0.12)
		&"lock": m.albedo_color = Color(0.12, 0.12, 0.14)
		&"peep":
			m.albedo_color = Color(0.1, 0.11, 0.13)
			m.metallic = 0.7
			m.roughness = 0.3
		&"peep_dark":
			m.albedo_color = Color(0.005, 0.005, 0.006)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		&"lamp_dead":
			m.albedo_color = Color(0.07, 0.075, 0.08)
		&"void":
			m.albedo_color = Color(0.012, 0.012, 0.014)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	# Мониторинг включается deferred: иначе area, созданная в кадре ребилда
	# (re-anchor), оценивает overlap по несинхронизированному трансформу и
	# стреляет ложным body_entered по игроку.
	area.monitoring = false
	area.set_deferred(&"monitoring", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	area.position = pos
	add_child(area)
	return area
