class_name FireSystem
extends Node3D
## Player-made fire (DESIGN_LOG iteration 1): "flame is a physical object, and a rifle round that hits flame
## detonates it." Owns the burst rule (a shot flare, cask or captain's lantern), oil pools, and the
## "burnable" group (casks, braziers, lanterns) that bursts chain into.
## Bursts: every Drowned inside burst_radius takes burst_damage, is knocked back and set burning; burnables
## inside it ignite after chain_delay; a short glare lights everything within burst_light_radius.

const BURNABLE: StringName = &"burnable"

@export_group("Burst")
@export var burst_radius: float = 6.0
@export var burst_damage: float = 60.0
@export var burst_knock: float = 2.0
@export var burst_light_radius: float = 20.0
@export var burst_light_time: float = 1.2
@export var burst_light_energy: float = 5.0
@export var burst_light_range: float = 9.0
@export var chain_delay: float = 0.15
@export_group("Oil pool")
@export var oil_pool_radius: float = 4.0       ## Drowned that glide through it catch fire
@export var oil_time: float = 12.0
@export var oil_light_radius: float = 9.0
@export var oil_light_dps: float = 12.0
@export var oil_light_energy: float = 3.5

var enemies: Enemies
var field: LightField
var audio: Soundscape
var island: Island
var weather: StormWeather

var bursts: int = 0
var oil_fires: int = 0


func setup(en: Enemies, lf: LightField, snd: Soundscape, isl: Island, wx: StormWeather) -> void:
	enemies = en
	field = lf
	audio = snd
	island = isl
	weather = wx


## Detonate flame at `pos`. `scale` shrinks or grows radius and damage (a cask is 0.8, a lantern 0.9).
func burst(pos: Vector3, scale: float = 1.0) -> void:
	bursts += 1
	var r: float = burst_radius * scale
	var glare: FireBurst = FireBurst.new()
	glare.name = "FireBurst"
	glare.field = field
	glare.radius = burst_light_radius
	glare.dps = 0.0
	glare.occludable = false
	glare.life = burst_light_time
	glare.peak_energy = burst_light_energy * scale
	glare.light_range = burst_light_range * scale
	add_child(glare)
	glare.global_position = pos
	FireFx.burst(self, pos, r)
	if audio != null:
		audio.play_whoomph(pos)
	if enemies != null:
		for d: Drowned in enemies.living():
			var to: Vector3 = d.chest_position() - pos
			if to.length() > r:
				continue
			var away: Vector3 = Vector3(to.x, 0.0, to.z)
			d.burst_hit(away, burst_damage * scale, burst_knock)
	for n: Node in get_tree().get_nodes_in_group(BURNABLE):
		var n3: Node3D = n as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		if n3.global_position.distance_to(pos) <= r:
			_ignite_later(n3)


func _ignite_later(n: Node3D) -> void:
	get_tree().create_timer(chain_delay, false, true).timeout.connect(func() -> void:
		if is_instance_valid(n) and n.is_inside_tree():
			n.call("ignite"))


## A burning pool of spilled oil on the ground at `pos` (lights, and sets alight what glides through).
func oil_fire(pos: Vector3) -> OilFire:
	oil_fires += 1
	var f: OilFire = OilFire.new()
	f.name = "OilFire"
	f.field = field
	f.hub = self
	f.radius = oil_light_radius
	f.dps = oil_light_dps
	f.life = oil_time
	f.pool_radius = oil_pool_radius
	f.energy = oil_light_energy
	add_child(f)
	var y: float = island.height_at(pos.x, pos.z) if island != null else pos.y
	f.global_position = Vector3(pos.x, y + 0.05, pos.z)
	return f


func telemetry() -> Dictionary:
	var burning: int = 0
	if enemies != null:
		for d: Drowned in enemies.living():
			if d.burning:
				burning += 1
	var pools: int = 0
	for c: Node in get_children():
		if c is OilFire:
			pools += 1
	return {
		"bursts": bursts,
		"oil_fires": oil_fires,
		"oil_active": pools,
		"drowned_burning": burning,
	}
