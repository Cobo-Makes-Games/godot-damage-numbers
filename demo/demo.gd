extends Node2D
## Damage Numbers demo. Buttons: a combo on one wolf, a wide swing that hits the
## whole pack, chipping a rock, getting hit. "Plain numbers" turns the rules off
## (no merging, no lanes, no colours) so you can compare.

const PACK: Array[Vector2] = [Vector2(470, 330), Vector2(500, 350), Vector2(530, 325), Vector2(492, 305), Vector2(515, 372)]
const ROCK: Vector2 = Vector2(690, 365)
const HERO: Vector2 = Vector2(405, 345)

var numbers: DamageNumbers
var plain: CheckBox
var mode_label: Label
var health: Array[int] = []
var flash: Dictionary = {}
var hero_flash: float = 0.0
var autoplay: bool = false
var clock: float = 0.0
var plan: Array = []
var combo_step: int = 0


func _ready() -> void:
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	seed(7)
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(530, 320)
	camera.zoom = Vector2(2, 2)
	add_child(camera)
	numbers = DamageNumbers.new()
	numbers.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(numbers)
	_reset_pack()
	_build_ui()
	if autoplay:
		# The same fight twice: plain numbers, then the rules.
		for pass_index: int in 2:
			var t: float = 0.3 + pass_index * 3.4
			plan.append([t - 0.3, "mode", pass_index == 1])
			for k: int in 4:
				plan.append([t + k * 0.13, "combo"])
			plan.append([t + 0.75, "swing"])
			plan.append([t + 1.0, "rock"])
			plan.append([t + 1.15, "rock"])
			plan.append([t + 1.3, "swing"])
			plan.append([t + 1.45, "hurt"])
		get_tree().create_timer(7.2).timeout.connect(func() -> void: get_tree().quit())


func _process(delta: float) -> void:
	clock += delta
	while not plan.is_empty() and clock >= float(plan[0][0]):
		var step: Array = plan.pop_front()
		match step[1]:
			"mode":
				plain.button_pressed = not step[2]
				_reset_pack()
				combo_step = 0
			"combo": _combo()
			"swing": _swing()
			"rock": _rock()
			"hurt": _hurt()
	for key: Variant in flash.keys():
		flash[key] = maxf(0.0, flash[key] - delta * 8.0)
	hero_flash = maxf(0.0, hero_flash - delta * 6.0)
	queue_redraw()


func _combo() -> void:
	_hit(0, [25, 26, 25, 24][combo_step % 4])
	combo_step += 1


func _swing() -> void:
	for i: int in PACK.size():
		_hit(i, 8 + randi() % 12)


func _rock() -> void:
	_show(ROCK + Vector2(0, -34), 4 + randi() % 3, DamageNumbers.Tone.RESOURCE, "hero", "rock", false)


func _hurt() -> void:
	hero_flash = 1.0
	_show(HERO + Vector2(0, -40), 12, DamageNumbers.Tone.TAKEN, "wolf", "hero", false)


func _hit(i: int, damage: int) -> void:
	if health[i] <= 0:
		health[i] = 100
	var final: bool = damage >= health[i]
	health[i] = maxi(0, health[i] - damage)
	flash[i] = 1.0
	_show(PACK[i] + Vector2(0, -30), damage, DamageNumbers.Tone.DEALT, "hero", "wolf%d" % i, final)


func _show(at: Vector2, amount: int, tone: DamageNumbers.Tone, attacker: String, target: String, final: bool) -> void:
	if plain.button_pressed:
		# What most games start with: every hit its own number, same spot, same colour.
		numbers.show_hit(at + Vector2(randf_range(-6, 6), 0), amount, DamageNumbers.Tone.RESOURCE, null, null, false, Color(1, 1, 1))
	else:
		numbers.show_hit(at, amount, tone, attacker, target, final)


func _reset_pack() -> void:
	health.clear()
	for i: int in PACK.size():
		health.append(100)
	if numbers != null:
		numbers.clear()


func _set_plain(on: bool) -> void:
	numbers.lanes = PackedVector2Array([Vector2.ZERO]) if on else DamageNumbers.new().lanes
	numbers.glyph_scale = 4 if on else 3  # plain numbers: one size for everything (resource tone is drawn one smaller)
	mode_label.text = "Plain numbers: one per hit, all white, all in the same spot" if on else "With the rules: combos tick one number up, colours by who's hurt, no overlaps"


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color("2f4a2c"))
	for i: int in 160:
		var p: Vector2 = Vector2(fmod(i * 97.3, 960.0), 140.0 + fmod(i * 53.7, 400.0))
		draw_rect(Rect2(p, Vector2(3, 3)), Color("3b5a35"))
	# Hero
	draw_circle(HERO + Vector2(0, 14), 16, Color(0, 0, 0, 0.25))
	draw_circle(HERO, 15, Color("f1dfb8").lerp(Color("ff5c4d"), hero_flash))
	draw_rect(Rect2(HERO + Vector2(8, -4), Vector2(26, 5)), Color("dde4ea"))
	# Pack
	for i: int in PACK.size():
		var p: Vector2 = PACK[i]
		draw_circle(p + Vector2(0, 12), 13, Color(0, 0, 0, 0.25))
		draw_circle(p, 12, Color("8a8f9c").lerp(Color.WHITE, flash.get(i, 0.0)))
		draw_rect(Rect2(p + Vector2(-12, 16), Vector2(24, 3)), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(p + Vector2(-12, 16), Vector2(24.0 * health[i] / 100.0, 3)), Color("ffb33d"))
	# Rock
	draw_colored_polygon(PackedVector2Array([ROCK + Vector2(-26, 16), ROCK + Vector2(-20, -10), ROCK + Vector2(0, -20), ROCK + Vector2(22, -8), ROCK + Vector2(28, 16)]), Color("8d8a83"))


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(16, 14)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.065, 0.085, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	for entry: Array in [["Combo on one wolf", _combo], ["Wide swing", _swing], ["Chip the rock", _rock], ["Get hit", _hurt]]:
		var b: Button = Button.new()
		b.text = entry[0]
		b.pressed.connect(entry[1])
		row.add_child(b)
	plain = CheckBox.new()
	plain.text = "Plain numbers"
	plain.toggled.connect(_set_plain)
	row.add_child(plain)
	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 17)
	box.add_child(mode_label)
	_set_plain(false)
