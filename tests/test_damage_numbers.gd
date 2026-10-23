extends SceneTree
## Headless checks: godot --headless --path . --script tests/test_damage_numbers.gd

var failures: int = 0


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func _layer() -> DamageNumbers:
	var n: DamageNumbers = DamageNumbers.new()
	n.drive_manually = true
	root.add_child(n)
	return n


func _boxes(n: DamageNumbers) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for e: Dictionary in n._numbers:
		var extent: Vector2 = DamageNumberFont.measure(e.text, n._scale_for(e.tone, e.big)) * (1.0 + n.pop_gain)
		out.append(Rect2(e.at - extent * 0.5, extent))
	return out


func _initialize() -> void:
	await process_frame
	var n: DamageNumbers = _layer()
	var hero: Node = Node.new()
	var wolf: Node = Node.new()
	var boar: Node = Node.new()
	check(n.show_hit(Vector2(100, 100), 9.6) == 10, "whole numbers: 9.6 shows 10")
	check(n.show_hit(Vector2(300, 100), 0.2) == 1, "every positive hit shows at least 1")
	check(n.show_hit(Vector2(300, 100), 0.0) == 0 and n.live_count() == 2, "no number for 0 damage")
	n.clear()

	# One attacker, one target: hits within 0.6 s tick one number up.
	n.show_hit(Vector2(100, 100), 25, DamageNumbers.Tone.DEALT, hero, wolf)
	n.advance(0.2)
	n.show_hit(Vector2(100, 100), 26, DamageNumbers.Tone.DEALT, hero, wolf)
	n.advance(0.2)
	var total: int = n.show_hit(Vector2(100, 100), 25, DamageNumbers.Tone.DEALT, hero, wolf)
	check(total == 76 and n.live_count() == 1, "a combo ticks one number up: 25, 51, 76 (one number on screen)")
	n.advance(0.5)
	check(n.live_count() == 1, "each tick restarts the number's 0.6 s life")
	n.advance(0.15)
	check(n.live_count() == 0, "gone 0.6 s after the last hit")
	n.show_hit(Vector2(100, 100), 5, DamageNumbers.Tone.DEALT, hero, wolf)
	n.advance(0.3)
	n.show_hit(Vector2(100, 100), 5, DamageNumbers.Tone.DEALT, hero, boar)
	check(n.live_count() == 2, "a different target gets its own number")
	n.show_hit(Vector2(100, 100), 5, DamageNumbers.Tone.DEALT, hero, boar, true)
	n.show_hit(Vector2(100, 100), 7, DamageNumbers.Tone.DEALT, hero, boar)
	check(n.live_count() == 3 and n._numbers[-1].count == 7, "a finishing blow closes its number; the next hit starts fresh")
	n.clear()

	# Big hits and finishing blows are one size larger; resource ticks one smaller.
	n.show_hit(Vector2.ZERO, 30, DamageNumbers.Tone.DEALT)
	n.show_hit(Vector2.ZERO, 3, DamageNumbers.Tone.DEALT, null, null, true)
	n.show_hit(Vector2.ZERO, 3, DamageNumbers.Tone.DEALT)
	n.show_hit(Vector2.ZERO, 3, DamageNumbers.Tone.RESOURCE)
	var sizes: Array = n._numbers.map(func(e: Dictionary) -> int: return n._scale_for(e.tone, e.big))
	check(sizes == [4, 4, 3, 2], "sizes: big 4, finishing 4, normal 3, resource 2 (%s)" % str(sizes))
	n.clear()

	# A wide swing hits five enemies standing together: no two numbers touch.
	for i: int in 5:
		n.show_hit(Vector2(200 + i * 6, 200), 10 + i * 7, DamageNumbers.Tone.DEALT, hero, "enemy%d" % i)
	var boxes: Array[Rect2] = _boxes(n)
	var touching: int = 0
	for a: int in boxes.size():
		for b: int in range(a + 1, boxes.size()):
			if boxes[a].intersects(boxes[b]):
				touching += 1
	check(touching == 0, "five numbers from one swing never touch, even at the peak of the pop")
	check(n._numbers[0].at == Vector2(200, 200), "the first number sits straight above its target")
	# Later hits (numbers already rising) still avoid them.
	n.advance(0.3)
	n.show_hit(Vector2(212, 200), 40, DamageNumbers.Tone.TAKEN)
	boxes.clear()
	for e: Dictionary in n._numbers:
		var extent: Vector2 = DamageNumberFont.measure(e.text, n._scale_for(e.tone, e.big)) * (1.0 + n.pop_gain)
		boxes.append(Rect2(e.at - Vector2(0, n.rise_speed * (n._clock - float(e.born))) - extent * 0.5, extent))
	var newest: Rect2 = boxes[-1]
	check(boxes.slice(0, -1).all(func(r: Rect2) -> bool: return not r.intersects(newest)), "a later hit lands clear of numbers that have already risen")
	n.clear()

	# Merged numbers keep their lane and ignore themselves.
	n.show_hit(Vector2(0, 0), 10, DamageNumbers.Tone.DEALT, hero, wolf)
	var first_at: Vector2 = n._numbers[0].at
	n.show_hit(Vector2(0, 0), 10, DamageNumbers.Tone.DEALT, hero, wolf)
	check(n._numbers[0].at == first_at, "a merged number doesn't hop away from its own old box")
	n.clear()

	check(n._pop(0.06) > 1.3 and is_equal_approx(n._pop(0.2), 1.0), "pops 35 % at 0.06 s, settled by 0.12 s")
	n.reduced_motion = true
	check(n._pop(0.06) == 1.0 and n._rise() == 0.0, "reduced motion: no pop and no rise")
	n.reduced_motion = false

	n.show_hit(Vector2.ZERO, 5, DamageNumbers.Tone.HEAL)
	check(n._numbers[0].text == "+5", "heals read +5")
	n.show_text(Vector2.ZERO, "Dodged")
	check(n.live_count() == 2, "words take a lane too")
	n.limit = 3
	for i: int in 10:
		n.show_hit(Vector2(i * 100, 0), 1)
	check(n.live_count() == 3, "the oldest go first past the limit")

	# Drawing runs without errors.
	n.limit = 64
	n.drive_manually = false
	await process_frame
	await process_frame
	for node: Node in [n, hero, wolf, boar]:
		node.free()
	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
