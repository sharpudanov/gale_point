class_name ProcAudio
extends RefCounted
## Procedural sound synthesis at boot (SPEC §4.13): 22 050 Hz mono 16-bit AudioStreamWAV buffers.
## Seeded from GameRng so every run sounds the same.

const RATE: int = 22050
const LOOP_XFADE: float = 0.5  ## seconds blended across the loop seam (no click)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = GameRng.next_seed()


static func _lp_coef(fc: float) -> float:
	return 1.0 - exp(-TAU * fc / RATE)


func _white() -> float:
	return _rng.randf() * 2.0 - 1.0


## Wind: pink noise through a one-pole lowpass sweeping 250-700 Hz with a 0.15 Hz gust envelope.
func wind(seconds: float = 12.0) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var total: int = n + int(LOOP_XFADE * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(total)
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	var y: float = 0.0
	var y2: float = 0.0
	var phase2: float = _rng.randf() * TAU
	for i: int in total:
		var t: float = float(i) / RATE
		var w: float = _white()
		b0 = 0.99765 * b0 + w * 0.0990460
		b1 = 0.96300 * b1 + w * 0.2965164
		b2 = 0.57000 * b2 + w * 1.0526913
		var pink: float = (b0 + b1 + b2 + w * 0.1848) * 0.2
		var gust: float = 0.5 + 0.35 * sin(TAU * 0.15 * t) + 0.15 * sin(TAU * 0.41 * t + phase2)
		var a: float = _lp_coef(lerpf(250.0, 700.0, gust))
		y += a * (pink - y)
		y2 += a * (y - y2)
		out[i] = y2 * (0.35 + 0.65 * gust)
	return _to_wav(out, n, true)


## Rain: white noise highpassed at 2 kHz plus random ticks at ~40/s.
func rain(seconds: float = 6.0) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var total: int = n + int(LOOP_XFADE * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(total)
	var lp: float = 0.0
	var lp2: float = 0.0
	var a: float = _lp_coef(2000.0)
	var tick_p: float = 40.0 / RATE
	var tick: float = 0.0
	for i: int in total:
		var w: float = _white()
		lp += a * (w - lp)
		var hp: float = w - lp
		lp2 += 0.5 * (hp - lp2)  # soften the top end a bit
		if _rng.randf() < tick_p:
			tick = _rng.randf_range(0.4, 1.0)
		tick *= 0.985
		out[i] = lp2 * 0.35 + tick * _white() * 0.6
	return _to_wav(out, n, true)


## Surf: brown noise, 0.1 Hz swell envelope, lowpass 500 Hz.
func surf(seconds: float = 10.0) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var total: int = n + int(LOOP_XFADE * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(total)
	var brown: float = 0.0
	var y: float = 0.0
	var a: float = _lp_coef(500.0)
	for i: int in total:
		var t: float = float(i) / RATE
		brown = (brown + 0.02 * _white()) / 1.02
		y += a * (brown * 3.5 - y)
		var swell: float = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(TAU * 0.1 * t - 1.2), 2.0)
		out[i] = y * swell
	return _to_wav(out, n, true)


## Thunder: 4 s of lowpassed brown noise with a crack and a random rumbling envelope.
func thunder(seconds: float = 4.0) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var brown: float = 0.0
	var y: float = 0.0
	var a: float = _lp_coef(320.0)
	var rumbles: Array[Vector2] = []  # (time, strength)
	for k: int in 6:
		rumbles.append(Vector2(_rng.randf_range(0.1, 2.6), _rng.randf_range(0.3, 1.0)))
	for i: int in n:
		var t: float = float(i) / RATE
		brown = (brown + 0.02 * _white()) / 1.02
		y += a * (brown * 3.5 - y)
		var env: float = 0.0
		for r: Vector2 in rumbles:
			var dt: float = t - r.x
			if dt > 0.0:
				env += r.y * exp(-dt * 1.6) * minf(1.0, dt * 12.0)
		var crack: float = exp(-t * 9.0) * 0.6
		var fade_out: float = clampf((seconds - t) / 0.6, 0.0, 1.0)
		out[i] = (y * env + _white() * crack * 0.25) * fade_out
	return _to_wav(out, n, false)


func _to_wav(src: PackedFloat32Array, n: int, loop: bool) -> AudioStreamWAV:
	var data: PackedFloat32Array = src
	if loop:
		# Crossfade the overhang into the start so the loop is seamless.
		var xf: int = src.size() - n
		data = src.slice(0, n)
		for i: int in xf:
			var k: float = float(i) / xf
			data[i] = src[i] * k + src[n + i] * (1.0 - k)
	var peak: float = 0.0001
	for v: float in data:
		peak = maxf(peak, absf(v))
	var gain: float = 0.9 / peak
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(data.size() * 2)
	for i: int in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] * gain, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size()
	return wav
