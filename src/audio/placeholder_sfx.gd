class_name PlaceholderSfx
extends RefCounted
## Процедурные ВРЕМЕННЫЕ звуки (BRIEF Section 6: допустимы с тегом PLACEHOLDER_).
## К M4 каждый ключ заменяется реальным файлом по ASSET_MANIFEST.md — имена
## ключей совпадают со slot_id манифеста, где это возможно.

const RATE: int = 22050

static func build_library() -> Dictionary:
	var lib: Dictionary = {}
	var steps: Array[AudioStream] = []
	for i: int in 6:
		steps.append(_wav(_footstep(0.07 + 0.02 * float(i % 3), 0.1 + 0.04 * float(i))))
	lib[&"PLACEHOLDER_footstep_concrete"] = steps
	lib[&"PLACEHOLDER_note_wire"] = [_wav(_wire_note())] as Array[AudioStream]
	lib[&"PLACEHOLDER_glitch"] = [_wav(_noise_burst(0.13, 0.42))] as Array[AudioStream]
	lib[&"PLACEHOLDER_rewind"] = [_wav(_rewind())] as Array[AudioStream]
	lib[&"PLACEHOLDER_door_slam"] = [_wav(_slam(55.0)), _wav(_slam(47.0))] as Array[AudioStream]
	var breaths: Array[AudioStream] = []
	for i: int in 3:
		breaths.append(_wav(_breath(0.6 + 0.1 * float(i))))
	lib[&"PLACEHOLDER_breath"] = breaths
	lib[&"PLACEHOLDER_amb_l1"] = [_wav(_ambience_loop(4.0), true)] as Array[AudioStream]
	return lib

# ------------------------------------------------------------- генераторы

static func _footstep(duration: float, lowpass: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	var y := 0.0
	for i: int in n:
		var t := float(i) / float(n)
		var x := rng.randf_range(-1.0, 1.0)
		y += lowpass * (x - y)
		out[i] = y * pow(1.0 - t, 3.0) * 0.9
	return out

static func _wire_note() -> PackedFloat32Array:
	var n := int(1.4 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t := float(i) / float(RATE)
		out[i] = sin(TAU * 1318.0 * t) * exp(-5.0 * t) * 0.28 \
			+ sin(TAU * 2659.0 * t) * exp(-9.0 * t) * 0.09
	return out

static func _noise_burst(duration: float, amp: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	for i: int in n:
		out[i] = rng.randf_range(-amp, amp)
	return out

static func _rewind() -> PackedFloat32Array:
	var n := int(1.1 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	var y := 0.0
	for i: int in n:
		var t := float(i) / float(RATE)
		var x := rng.randf_range(-1.0, 1.0)
		y += 0.35 * (x - y)
		var warble := 0.55 + 0.45 * sin(TAU * 13.0 * t * (1.0 + t))
		out[i] = y * warble * 0.4 + sin(TAU * (300.0 + 1400.0 * t) * t) * 0.07
	return out

static func _slam(freq: float) -> PackedFloat32Array:
	var n := int(0.55 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	for i: int in n:
		var t := float(i) / float(RATE)
		out[i] = sin(TAU * freq * t) * exp(-11.0 * t) * 0.8 \
			+ rng.randf_range(-1.0, 1.0) * exp(-32.0 * t) * 0.35
	return out

static func _breath(duration: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	var y := 0.0
	for i: int in n:
		var t := float(i) / float(n)
		var x := rng.randf_range(-1.0, 1.0)
		y += 0.06 * (x - y)
		out[i] = y * pow(sin(PI * t), 1.5) * 1.6
	return out

static func _ambience_loop(duration: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	var brown := 0.0
	var wind := 0.0
	for i: int in n:
		var t := float(i) / float(RATE)
		brown = clampf(brown * 0.997 + rng.randf_range(-1.0, 1.0) * 0.08, -1.0, 1.0)
		wind += 0.002 * (rng.randf_range(-1.0, 1.0) - wind)
		out[i] = brown * 0.22 + wind * 2.2 * (0.6 + 0.4 * sin(TAU * 0.11 * t)) \
			+ sin(TAU * 50.0 * t) * 0.025
	# плавный кроссфейд краёв, чтобы луп не щёлкал
	var fade := int(0.05 * RATE)
	for i: int in fade:
		var k := float(i) / float(fade)
		out[i] *= k
		out[n - 1 - i] *= k
	return out

static func _wav(samples: PackedFloat32Array, looped: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
