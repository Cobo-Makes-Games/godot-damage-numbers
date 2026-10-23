class_name DamageNumberFont
extends RefCounted
## A 5 x 7 pixel alphabet with a one-pixel dark edge baked in, so numbers stay
## crisp and readable over bright grass, pale sand or snow without a box behind
## them. Digits, + - . ? and a to z. Drawn from two small generated textures.

const GLYPHS: Dictionary = {
	"a":[".###.","#...#","#...#","#####","#...#","#...#","#...#"],
	"b":["####.","#...#","#...#","####.","#...#","#...#","####."],
	"c":[".####","#....","#....","#....","#....","#....",".####"],
	"d":["####.","#...#","#...#","#...#","#...#","#...#","####."],
	"e":["#####","#....","#....","####.","#....","#....","#####"],
	"f":["#####","#....","#....","####.","#....","#....","#...."],
	"g":[".####","#....","#....","#.###","#...#","#...#",".###."],
	"h":["#...#","#...#","#...#","#####","#...#","#...#","#...#"],
	"i":[".###.","..#..","..#..","..#..","..#..","..#..",".###."],
	"j":["..###","...#.","...#.","...#.","#..#.","#..#.",".##.."],
	"k":["#...#","#..#.","#.#..","##...","#.#..","#..#.","#...#"],
	"l":["#....","#....","#....","#....","#....","#....","#####"],
	"m":["#...#","##.##","#.#.#","#.#.#","#...#","#...#","#...#"],
	"n":["#...#","##..#","##..#","#.#.#","#..##","#..##","#...#"],
	"o":[".###.","#...#","#...#","#...#","#...#","#...#",".###."],
	"p":["####.","#...#","#...#","####.","#....","#....","#...."],
	"q":[".###.","#...#","#...#","#...#","#.#.#","#..#.",".##.#"],
	"r":["####.","#...#","#...#","####.","#.#..","#..#.","#...#"],
	"s":[".####","#....","#....",".###.","....#","....#","####."],
	"t":["#####","..#..","..#..","..#..","..#..","..#..","..#.."],
	"u":["#...#","#...#","#...#","#...#","#...#","#...#",".###."],
	"v":["#...#","#...#","#...#","#...#",".#.#.",".#.#.","..#.."],
	"w":["#...#","#...#","#...#","#.#.#","#.#.#","##.##","#...#"],
	"x":["#...#","#...#",".#.#.","..#..",".#.#.","#...#","#...#"],
	"y":["#...#","#...#",".#.#.","..#..","..#..","..#..","..#.."],
	"z":["#####","....#","...#.","..#..",".#...","#....","#####"],
	"0":[".###.","#...#","#..##","#.#.#","##..#","#...#",".###."],
	"1":["..#..",".##..","..#..","..#..","..#..","..#..",".###."],
	"2":[".###.","#...#","....#","...#.","..#..",".#...","#####"],
	"3":["####.","....#","....#",".###.","....#","....#","####."],
	"4":["...#.","..##.",".#.#.","#..#.","#####","...#.","...#."],
	"5":["#####","#....","#....","####.","....#","....#","####."],
	"6":[".###.","#....","#....","####.","#...#","#...#",".###."],
	"7":["#####","....#","...#.","..#..",".#...",".#...",".#..."],
	"8":[".###.","#...#","#...#",".###.","#...#","#...#",".###."],
	"9":[".###.","#...#","#...#",".####","....#","....#",".###."],
	"+":[".....","..#..","..#..","#####","..#..","..#..","....."],
	"-":[".....",".....",".....","#####",".....",".....","....."],
	".":[".....",".....",".....",".....",".....",".##..",".##.."],
	"?":[".###.","#...#","....#","..##.","..#..",".....","..#.."]
}

static var _fill: ImageTexture
static var _edge: ImageTexture
static var _regions: Dictionary = {}


## Size in pixels of `text` drawn at `scale` (glyph pixels per screen pixel), edge not included.
static func measure(text: String, scale: int) -> Vector2:
	return Vector2(maxi(0, text.length() * 6 - 1) * scale, 7 * scale)


## Draws `text` with its top-left corner at `top_left`.
static func draw(canvas: CanvasItem, text: String, top_left: Vector2, scale: int, fill: Color, edge: Color) -> void:
	_ensure()
	var cursor: Vector2 = top_left.round()
	for character: String in text.to_lower():
		if character != " ":
			var source: Rect2 = _regions.get(character, _regions["?"])
			var target: Rect2 = Rect2(cursor - Vector2.ONE * scale, Vector2(8, 10) * scale)
			canvas.draw_texture_rect_region(_edge, target, source, edge)
			canvas.draw_texture_rect_region(_fill, target, source, fill)
		cursor.x += 6 * scale


static func _ensure() -> void:
	if _fill != null:
		return
	var characters: Array = GLYPHS.keys()
	var fill: Image = Image.create(16 * 8, ceili(float(characters.size()) / 16.0) * 10, false, Image.FORMAT_RGBA8)
	var edge: Image = Image.create(fill.get_width(), fill.get_height(), false, Image.FORMAT_RGBA8)
	fill.fill(Color.TRANSPARENT)
	edge.fill(Color.TRANSPARENT)
	for index: int in characters.size():
		var character: String = str(characters[index])
		var origin: Vector2i = Vector2i((index % 16) * 8, (index / 16) * 10)
		var rows: Array = GLYPHS[character]
		for y: int in 7:
			for x: int in 5:
				if rows[y][x] == "#":
					fill.set_pixel(origin.x + x + 1, origin.y + y + 1, Color.WHITE)
					for dy: int in range(-1, 2):
						for dx: int in range(-1, 2):
							edge.set_pixel(origin.x + x + 1 + dx, origin.y + y + 1 + dy, Color.WHITE)
		_regions[character] = Rect2(origin, Vector2(8, 10))
	_fill = ImageTexture.create_from_image(fill)
	_edge = ImageTexture.create_from_image(edge)
