@icon("res://addons/damage_numbers/icon.svg")
class_name DamageNumbers
extends Node2D
## Floating damage numbers that stay readable in a busy fight:
## - whole numbers, and every hit shows at least 1;
## - rapid hits by one attacker on one target tick a single number up;
## - the colour says who was hurt (cream on objects, gold on enemies, red on you);
## - a finishing blow or a big hit is one size larger;
## - each new number takes the nearest free spot of 13 around its target, so
##   numbers for different targets never touch, even at the peak of their pop;
## - a pixel font with a dark edge, and 0.6 seconds from pop to gone.
##
## Add one DamageNumbers node to your world (anywhere; it draws in world space)
## and call show_hit() where damage is dealt:
##
##   $DamageNumbers.show_hit(enemy.global_position + Vector2(0, -24), 12,
##       DamageNumbers.Tone.DEALT, self, enemy, enemy.health <= 0)
##
## From Mytheria (cobomakesgames.com/blog/damage-numbers/).

enum Tone { RESOURCE, DEALT, TAKEN, HEAL }

const _FILLS: Dictionary = {
	Tone.RESOURCE: Color(0.93, 0.89, 0.76),
	Tone.DEALT: Color(1.0, 0.7, 0.24),
	Tone.TAKEN: Color(1.0, 0.36, 0.3),
	Tone.HEAL: Color(0.72, 0.9, 0.63),
}
const _EDGES: Dictionary = {
	Tone.RESOURCE: Color(0.045, 0.09, 0.075),
	Tone.DEALT: Color(0.07, 0.05, 0.03),
	Tone.TAKEN: Color(0.22, 0.02, 0.04),
	Tone.HEAL: Color(0.03, 0.08, 0.03),
}

## Spots tried for a new number, nearest first, in pixels at glyph_scale 3.
## They grow with glyph_scale, so larger text keeps the same clear gaps.
@export var lanes: PackedVector2Array = PackedVector2Array([
	Vector2.ZERO, Vector2(0, -50), Vector2(-76, -20), Vector2(76, -20), Vector2(0, 50),
	Vector2(-76, 36), Vector2(76, 36), Vector2(0, -100), Vector2(-80, -76), Vector2(80, -76),
	Vector2(-152, -20), Vector2(152, -20), Vector2(0, -150),
])
## Seconds a number lives. Short, so the screen only holds what just happened.
@export_range(0.1, 3.0, 0.05) var lifetime: float = 0.6
## Hits with the same merge key within this window tick one number up.
@export_range(0.0, 3.0, 0.05) var merge_window: float = 0.6
## Rise speed in pixels a second (0 with reduced_motion).
@export_range(0.0, 200.0, 1.0) var rise_speed: float = 22.0
## The pop on each new hit: this much larger at its peak, over pop_seconds.
@export_range(0.0, 1.0, 0.01) var pop_gain: float = 0.35
@export_range(0.01, 0.5, 0.01) var pop_seconds: float = 0.12
## Glyph pixel size for normal numbers (big ones are one step larger, resource ticks one smaller).
@export_range(1, 8) var glyph_scale: int = 3
## A hit at least this big is drawn one size larger. 0 turns it off.
@export var big_hit: int = 25
## Fades the colour toward darker as a number ages, so the freshest hit reads brightest.
@export_range(0.0, 1.0, 0.05) var age_dim: float = 0.35
## Reduced motion: numbers don't rise or pop.
@export var reduced_motion: bool = false
## Most numbers alive at once; the oldest goes first.
@export_range(1, 512) var limit: int = 64

var _numbers: Array[Dictionary] = []
var _clock: float = 0.0
## Set this and call advance() yourself to run on your own clock.
var drive_manually: bool = false


## Shows `amount` at `at` (this node's coordinates). Pass the attacker and
## target (any values: nodes, ids) to merge rapid hits into one number; leave
## them null for one number per call. `final` marks a finishing blow (larger).
## `color` overrides the tone colour, for a partner's hits in their player colour.
## Returns the number shown (the merged total when it merged).
func show_hit(at: Vector2, amount: float, tone: Tone = Tone.DEALT, attacker: Variant = null, target: Variant = null, final: bool = false, color: Color = Color(0, 0, 0, 0)) -> int:
	var whole: int = maxi(1, roundi(amount)) if amount > 0.0 else 0
	if whole <= 0:
		return 0
	var key: String = _key(attacker, target)
	var existing: Dictionary = _recent(key)
	var total: int = whole + int(existing.get("count", 0))
	var big: bool = tone != Tone.RESOURCE and tone != Tone.HEAL and (final or (big_hit > 0 and whole >= big_hit) or bool(existing.get("big", false)))
	var text: String = ("+" if tone == Tone.HEAL else "") + str(total)
	var scale: int = _scale_for(tone, big)
	var offset: Vector2 = _free_lane(at, text, scale, key)
	if existing.is_empty():
		existing = {"key": key}
		if _numbers.size() >= limit:
			_numbers.pop_front()
		_numbers.append(existing)
	existing.count = total
	existing.text = text
	existing.tone = tone
	existing.big = big
	existing.final = final
	existing.color = color
	existing.born = _clock
	existing.at = at + offset
	queue_redraw()
	return total


## Shows a short word ("Dodged", "Miss", "+4 stone") in the given tone, using a lane like a number.
func show_text(at: Vector2, text: String, tone: Tone = Tone.RESOURCE, color: Color = Color(0, 0, 0, 0)) -> void:
	var scale: int = _scale_for(tone, false)
	var entry: Dictionary = {"key": "", "count": 0, "text": text, "tone": tone, "big": false, "color": color, "born": _clock}
	entry.at = at + _free_lane(at, text, scale, "")
	if _numbers.size() >= limit:
		_numbers.pop_front()
	_numbers.append(entry)
	queue_redraw()


## Numbers on screen now (for tests and debug overlays).
func live_count() -> int:
	return _numbers.size()


## Removes every number.
func clear() -> void:
	_numbers.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if not drive_manually:
		advance(delta)


func advance(delta: float) -> void:
	_clock += maxf(0.0, delta)
	for i: int in range(_numbers.size() - 1, -1, -1):
		if _clock - float(_numbers[i].born) >= lifetime:
			_numbers.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for entry: Dictionary in _numbers:
		var age: float = _clock - float(entry.born)
		var scale: int = _scale_for(entry.tone, entry.big)
		var extent: Vector2 = DamageNumberFont.measure(entry.text, scale)
		var point: Vector2 = (entry.at - Vector2(0, _rise() * age)).round()
		var alpha: float = clampf((lifetime - age) * 4.5, 0.0, 1.0)
		var dim: float = clampf(age / lifetime, 0.0, 1.0) * age_dim * 0.6
		var base: Color = entry.color if entry.color.a > 0.0 else _FILLS[entry.tone]
		var fill: Color = Color(base.r * (1.0 - dim), base.g * (1.0 - dim), base.b * (1.0 - dim), alpha)
		var edge: Color = Color(_EDGES[entry.tone], alpha)
		var pop: float = _pop(age)
		draw_set_transform(point, 0.0, Vector2(pop, pop))
		DamageNumberFont.draw(self, entry.text, -extent * 0.5, scale, fill, edge)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _pop(age: float) -> float:
	if reduced_motion:
		return 1.0
	var q: float = age / pop_seconds
	if q <= 0.0 or q >= 1.0:
		return 1.0
	return 1.0 + pop_gain * sin(PI * q)


func _rise() -> float:
	return 0.0 if reduced_motion else rise_speed


func _scale_for(tone: Tone, big: bool) -> int:
	var base: int = glyph_scale
	if tone == Tone.RESOURCE:
		base = maxi(1, base - 1)
	return base + 1 if big else base


func _key(attacker: Variant, target: Variant) -> String:
	if attacker == null or target == null:
		return ""
	return "%s>%s" % [_id(attacker), _id(target)]


func _id(value: Variant) -> String:
	return str(value.get_instance_id()) if value is Object else str(value)


func _recent(key: String) -> Dictionary:
	if key.is_empty():
		return {}
	for entry: Dictionary in _numbers:
		# A finishing blow closes its number: a respawned or new target starts fresh.
		if entry.key == key and _clock - float(entry.born) < merge_window and not entry.get("final", false):
			return entry
	return {}


## The nearest lane whose box (at the peak of its pop, plus a one-glyph-pixel
## gap) is clear of every other live number. If none is clear, the one with the
## least overlap.
func _free_lane(source: Vector2, text: String, scale: int, own_key: String) -> Vector2:
	var extent: Vector2 = _footprint(text, scale)
	var others: Array[Rect2] = []
	for entry: Dictionary in _numbers:
		if not own_key.is_empty() and entry.key == own_key:
			continue
		var age: float = _clock - float(entry.born)
		var other_extent: Vector2 = _footprint(entry.text, _scale_for(entry.tone, entry.big))
		# Every number rises at the same speed, so where they are now relative to
		# each other is where they stay: today's box is the whole story.
		var now_at: Vector2 = entry.at - Vector2(0, _rise() * age)
		others.append(Rect2(now_at - other_extent * 0.5, other_extent))
	var best: Vector2 = Vector2.ZERO
	var best_overlap: float = INF
	var spread: float = float(glyph_scale) / 3.0
	for lane: Vector2 in lanes:
		var box: Rect2 = Rect2(source + lane * spread - extent * 0.5, extent)
		var overlap: float = 0.0
		for other: Rect2 in others:
			if box.intersects(other):
				overlap += box.intersection(other).get_area()
		if overlap <= 0.0:
			return lane * spread
		if overlap < best_overlap:
			best_overlap = overlap
			best = lane * spread
	return best


func _footprint(text: String, scale: int) -> Vector2:
	return DamageNumberFont.measure(text, scale) * (1.0 + pop_gain) + Vector2.ONE * float(scale) * 2.0
