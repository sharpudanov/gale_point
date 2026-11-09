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


## Rifle crack: 20 ms noise burst + 90 Hz thump (0.25 s) + 1.8 s lowpassed echo tail with two slap-backs.
func rifle_crack(seconds: float = 2.2) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var tail_lp: float = 0.0
	var tail_lp2: float = 0.0
	var a: float = _lp_coef(700.0)
	var echoes: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(0.28, 0.45), Vector2(0.65, 0.3)]  # (delay s, gain)
	for i: int in n:
		var t: float = float(i) / RATE
		var w: float = _white()
		var crack: float = w * exp(-t / 0.005) if t < 0.02 else 0.0
		var thump: float = sin(TAU * 90.0 * t) * exp(-t * 14.0)
		tail_lp += a * (w - tail_lp)
		tail_lp2 += a * (tail_lp - tail_lp2)
		var tail: float = 0.0
		for e: Vector2 in echoes:
			var dt: float = t - e.x
			if dt > 0.0:
				tail += e.y * exp(-dt * 2.3) * minf(1.0, dt * 60.0)
		out[i] = crack * 1.0 + thump * 0.8 + tail_lp2 * tail * 6.0 * (1.0 if t > 0.015 else 0.0)
		out[i] *= clampf((seconds - t) / 0.3, 0.0, 1.0)
	return _to_wav(out, n, false)


## One short filtered click: damped sine plus a pinch of noise.
func _click(out: PackedFloat32Array, start: float, freq: float, gain: float) -> void:
	var len_s: int = int(0.008 * RATE)
	var s0: int = int(start * RATE)
	for i: int in len_s:
		if s0 + i >= out.size():
			return
		var t: float = float(i) / RATE
		var env: float = exp(-t / 0.0022)
		out[s0 + i] += (sin(TAU * freq * t) * 0.8 + _white() * 0.2) * env * gain


## Bolt clack: two clicks (1.8 kHz, 1.2 kHz) 70 ms apart.
func bolt_clack() -> AudioStreamWAV:
	var n: int = int(0.14 * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	_click(out, 0.0, 1800.0, 1.0)
	_click(out, 0.07, 1200.0, 0.8)
	return _to_wav(out, n, false)


## Reload click: a lighter pair, 45 ms apart.
func reload_click() -> AudioStreamWAV:
	var n: int = int(0.1 * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	_click(out, 0.0, 1200.0, 0.8)
	_click(out, 0.045, 1800.0, 1.0)
	return _to_wav(out, n, false)


## Flare launch: low thump plus a bandpassed whoosh (0.7 s).
func flare_launch(seconds: float = 0.7) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var lp2: float = 0.0
	var a_top: float = _lp_coef(2500.0)
	var a_bottom: float = _lp_coef(300.0)
	for i: int in n:
		var t: float = float(i) / RATE
		var w: float = _white()
		lp += a_top * (w - lp)
		lp2 += a_bottom * (lp - lp2)
		var band: float = lp - lp2  # 300 Hz - 2.5 kHz
		var thump: float = sin(TAU * (110.0 - 60.0 * t) * t) * exp(-t * 10.0)
		var whoosh: float = band * minf(1.0, t * 30.0) * exp(-t * 3.5)
		out[i] = thump * 0.9 + whoosh * 2.0 + w * exp(-t / 0.004) * 0.5
		out[i] *= clampf((seconds - t) / 0.1, 0.0, 1.0)
	return _to_wav(out, n, false)


## Flare hiss: bandpassed 3-6 kHz noise with crackle (~25/s). A 4 s loop; the flare scales the volume
## to follow the burn curve and sputter.
func flare_hiss(seconds: float = 4.0) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var total: int = n + int(LOOP_XFADE * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(total)
	var lp_a: float = 0.0
	var lp_b: float = 0.0
	var lp_c: float = 0.0
	var a_hi: float = _lp_coef(3000.0)
	var a_lo: float = _lp_coef(6000.0)
	var crackle_p: float = 25.0 / RATE
	var crackle: float = 0.0
	for i: int in total:
		var w: float = _white()
		lp_a += a_hi * (w - lp_a)
		var hp: float = w - lp_a          # highpass 3 kHz
		lp_b += a_lo * (hp - lp_b)        # lowpass 6 kHz
		lp_c += a_lo * (lp_b - lp_c)
		if _rng.randf() < crackle_p:
			crackle = _rng.randf_range(0.5, 1.0)
		crackle *= 0.97
		out[i] = lp_c * 1.4 + crackle * _white() * 0.8
	return _to_wav(out, n, true)


## Kill thud (SPEC 4.13): 60 -> 35 Hz sine drop over 0.35 s, a 120 ms lowpassed noise slap and a faint wet
## splash (bandpass noise 1.2 kHz, 80 ms). 0.5 s total.
func kill_thud(seconds: float = 0.5) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var slap_lp: float = 0.0
	var a: float = _lp_coef(400.0)
	var band: Vector2 = Vector2.ZERO  # state-variable filter (low, band)
	var f: float = 2.0 * sin(PI * 1200.0 / RATE)
	for i: int in n:
		var t: float = float(i) / RATE
		var hz: float = lerpf(60.0, 35.0, clampf(t / 0.35, 0.0, 1.0))
		phase += TAU * hz / RATE
		var body: float = sin(phase) * exp(-t * 7.0) * minf(1.0, t * 400.0)
		var w: float = _white()
		slap_lp += a * (w - slap_lp)
		var slap: float = slap_lp * 4.0 * exp(-t / 0.04) if t < 0.12 else 0.0
		var high: float = w - band.x - 0.35 * band.y
		band.y += f * high
		band.x += f * band.y
		var splash: float = band.y * 0.5 * exp(-t / 0.03) if t < 0.08 else 0.0
		out[i] = (body * 1.0 + slap * 0.7 + splash * 0.25) * clampf((seconds - t) / 0.08, 0.0, 1.0)
	return _to_wav(out, n, false)


## Dark-hit deflect: a dull, hollow metallic "tonk" - two inharmonic sine partials (230 / 610 Hz, the upper one
## decaying fast) under a short lowpassed noise tick, 0.28 s. Deliberately not the sharp rifle crack.
func dark_deflect(seconds: float = 0.28) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var tick_lp: float = 0.0
	var a: float = _lp_coef(1800.0)
	for i: int in n:
		var t: float = float(i) / RATE
		var low: float = sin(TAU * 230.0 * t) * exp(-t * 16.0)
		var mid: float = sin(TAU * 610.0 * t + 0.6) * exp(-t * 38.0) * 0.55
		var w: float = _white()
		tick_lp += a * (w - tick_lp)
		var tick: float = tick_lp * 1.6 * exp(-t / 0.012)
		out[i] = (low * 0.8 + mid + tick * 0.5) * minf(1.0, t * 600.0) * clampf((seconds - t) / 0.05, 0.0, 1.0)
	return _to_wav(out, n, false)


## Moan variants (SPEC 4.13): a saw at 90-140 Hz with a slow pitch glide, 5 Hz vibrato, two formant
## bandpasses (500 / 1500 Hz) and breath noise, 1.8-3.2 s.
func moan(variant: int) -> AudioStreamWAV:
	var vrng: RandomNumberGenerator = RandomNumberGenerator.new()
	vrng.seed = 7919 * (variant + 1)
	var seconds: float = vrng.randf_range(1.8, 3.2)
	var base: float = vrng.randf_range(90.0, 140.0)
	var glide: float = vrng.randf_range(-0.22, 0.18)
	var n: int = int(seconds * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var f1: float = 2.0 * sin(PI * 500.0 / RATE)
	var f2: float = 2.0 * sin(PI * 1500.0 / RATE)
	var s1: Vector2 = Vector2.ZERO
	var s2: Vector2 = Vector2.ZERO
	var breath_lp: float = 0.0
	var breath_a: float = _lp_coef(900.0)
	for i: int in n:
		var t: float = float(i) / RATE
		var u: float = t / seconds
		var hz: float = base * (1.0 + glide * sin(PI * u)) * (1.0 + 0.025 * sin(TAU * 5.0 * t))
		phase = fmod(phase + hz / RATE, 1.0)
		var saw: float = phase * 2.0 - 1.0
		var low: float = saw * 0.5
		var h1: float = saw - s1.x - 0.12 * s1.y
		s1.y += f1 * h1
		s1.x += f1 * s1.y
		var h2: float = saw - s2.x - 0.12 * s2.y
		s2.y += f2 * h2
		s2.x += f2 * s2.y
		var w: float = _white()
		breath_lp += breath_a * (w - breath_lp)
		var env: float = pow(sin(PI * clampf(u, 0.0, 1.0)), 0.8) * (0.8 + 0.2 * sin(TAU * 0.9 * t + float(variant)))
		out[i] = (low * 0.25 + s1.y * 0.9 + s2.y * 0.45 + breath_lp * 0.5) * env
	return _to_wav(out, n, false)


## Ember crackle (wounded smolder / burning cloth): sparse sharp pops (~14/s) of highpassed noise over a faint
## lowpassed hiss bed. A 3 s loop; the Drowned scales the volume with its wound.
func ember_crackle(seconds: float = 3.0) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var total: int = n + int(LOOP_XFADE * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(total)
	var pop_p: float = 14.0 / RATE
	var pop: float = 0.0
	var pop_decay: float = 0.99
	var hp_lp: float = 0.0
	var bed_lp: float = 0.0
	var a_hp: float = _lp_coef(1500.0)
	var a_bed: float = _lp_coef(700.0)
	for i: int in total:
		var w: float = _white()
		if _rng.randf() < pop_p:
			pop = _rng.randf_range(0.4, 1.0)
			pop_decay = _rng.randf_range(0.985, 0.996)
		pop *= pop_decay
		hp_lp += a_hp * (w - hp_lp)
		bed_lp += a_bed * (w - bed_lp)
		out[i] = (w - hp_lp) * pop * 1.2 + bed_lp * 0.12
	return _to_wav(out, n, true)


## Rifle-butt strike: a hollow wooden knock (two short partials 180 / 740 Hz), a lowpassed cloth slap and a
## 95 Hz body thump. 0.32 s.
func butt_strike(seconds: float = 0.32) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var slap_lp: float = 0.0
	var a: float = _lp_coef(1200.0)
	for i: int in n:
		var t: float = float(i) / RATE
		var knock: float = sin(TAU * 180.0 * t) * exp(-t * 30.0) + sin(TAU * 740.0 * t + 0.4) * exp(-t * 70.0) * 0.5
		var thump: float = sin(TAU * 95.0 * t) * exp(-t * 14.0)
		slap_lp += a * (_white() - slap_lp)
		var slap: float = slap_lp * 3.0 * exp(-t / 0.035)
		out[i] = (knock * 0.7 + thump * 0.8 + slap * 0.6) * minf(1.0, t * 900.0) * clampf((seconds - t) / 0.05, 0.0, 1.0)
	return _to_wav(out, n, false)


## Air whoosh for a shove that hits nothing: bandpassed noise swelling and falling over 0.22 s.
func swing_whoosh(seconds: float = 0.22) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var band: Vector2 = Vector2.ZERO
	for i: int in n:
		var t: float = float(i) / RATE
		var u: float = t / seconds
		var fc: float = lerpf(500.0, 1600.0, u)
		var f: float = 2.0 * sin(PI * fc / RATE)
		var high: float = _white() - band.x - 0.6 * band.y
		band.y += f * high
		band.x += f * band.y
		out[i] = band.y * sin(PI * u)
	return _to_wav(out, n, false)


## Sea bell (buoys): a struck bronze bell, inharmonic partials (hum 0.5, prime 1, tierce 1.2, quint 1.5,
## nominal 2, 2.6, 3.4 x f0) each with its own decay, plus a short clapper tick. `f0` Hz, 4.5 s.
func sea_bell(f0: float = 220.0, seconds: float = 4.5) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var ratios: PackedFloat32Array = PackedFloat32Array([0.5, 1.0, 1.19, 1.5, 2.0, 2.61, 3.42])
	var gains: PackedFloat32Array = PackedFloat32Array([0.55, 1.0, 0.6, 0.35, 0.5, 0.25, 0.18])
	var decays: PackedFloat32Array = PackedFloat32Array([0.45, 0.9, 1.3, 1.6, 1.9, 3.5, 5.0])
	var tick_lp: float = 0.0
	var a: float = _lp_coef(2500.0)
	for i: int in n:
		var t: float = float(i) / RATE
		var v: float = 0.0
		for k: int in ratios.size():
			v += sin(TAU * f0 * ratios[k] * t + float(k)) * gains[k] * exp(-t * decays[k])
		tick_lp += a * (_white() - tick_lp)
		v += tick_lp * 1.5 * exp(-t / 0.01)
		out[i] = v * minf(1.0, t * 800.0) * clampf((seconds - t) / 0.3, 0.0, 1.0)
	return _to_wav(out, n, false)


## Fire whoomph (oil / magnesium burst): a low 45 -> 80 Hz swell under roaring lowpassed noise that opens
## from 300 Hz to 2.5 kHz, with crackle on the tail. 1.4 s.
func fire_whoomph(seconds: float = 1.4) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var lp2: float = 0.0
	var phase: float = 0.0
	var pop: float = 0.0
	for i: int in n:
		var t: float = float(i) / RATE
		var u: float = t / seconds
		var env: float = minf(1.0, t / 0.06) * exp(-t * 2.2)
		var a: float = _lp_coef(lerpf(300.0, 2500.0, minf(1.0, t / 0.15)) * (1.0 - 0.6 * u))
		var w: float = _white()
		lp += a * (w - lp)
		lp2 += a * (lp - lp2)
		phase += TAU * lerpf(45.0, 80.0, minf(1.0, t / 0.2)) / RATE
		if _rng.randf() < 30.0 / RATE:
			pop = _rng.randf_range(0.3, 0.8)
		pop *= 0.992
		out[i] = (lp2 * 2.2 + sin(phase) * 0.9 * exp(-t * 4.0) + w * pop * 0.5 * u) * env
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
