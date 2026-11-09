extends SceneTree
## Gerador dos ícones das 9 habilidades novas (PNG 32x32, fundo transparente, desenhados por código).
## É reproduzível: roda sempre com o mesmo resultado e não usa nenhum asset de fora.
##   godot --headless --path . --script res://tests/gerar_icones.gd
## Saída: res://abilities/icons/<id>.png e a folha de contato res://tests/icones_novas_habilidades.png.
## Depois de gerar, rode `godot --headless --path . --import --quit` para o Godot criar os `.import`.
##
## Estilo igual ao dos glifos desenhados do `AmuletIcon`: traço único na cor da raridade (cinza,
## azul, dourado claro), sem contorno, e um segundo tom mais escuro para os detalhes.
## Cada ícone é uma função (ponto -> camada): 0 vazio, 1 cor da raridade, 2 tom escuro, 3 destaque.

const SIZE: int = 32
## Amostras por eixo em cada pixel (suaviza as bordas, como o desenho vetorial do jogo).
const SAMPLES: int = 4
const OUT_DIR: String = "res://abilities/icons/"
const SHEET_PATH: String = "res://tests/icones_novas_habilidades.png"
const SHEET_SCALE: int = 8
const SHEET_GAP: int = 24

const COLOR_COMMON: Color = Color("#8c97a3")
const COLOR_ADVANCED: Color = Color("#8fd0f0")
const COLOR_LEGENDARY: Color = Color("#fff0b0")
const COLOR_ACCENT: Color = Color("#ff9a3c")
const COLOR_SHEET_BG: Color = Color("#14100c")
const DARKEN: float = 0.4

## id do arquivo -> [função do ícone, cor da raridade]
var _icons: Dictionary = {}


func _init() -> void:
	_icons = {
		"reflexos": [_reflexos, COLOR_COMMON],
		"carga_rapida": [_carga_rapida, COLOR_COMMON],
		"pele_de_ferro": [_pele_de_ferro, COLOR_COMMON],
		"pulso_gelido": [_pulso_gelido, COLOR_ADVANCED],
		"mina_binaria": [_mina_binaria, COLOR_ADVANCED],
		"drone_aliado": [_drone_aliado, COLOR_ADVANCED],
		"tiro_em_leque": [_tiro_em_leque, COLOR_ADVANCED],
		"maquina_enigma": [_maquina_enigma, COLOR_LEGENDARY],
		"overclock": [_overclock, COLOR_LEGENDARY],
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var images: Array[Image] = []
	for id: String in _icons:
		var spec: Array = _icons[id]
		var image: Image = _render(spec[0] as Callable, spec[1] as Color)
		var path: String = ProjectSettings.globalize_path(OUT_DIR + id + ".png")
		var erro: Error = image.save_png(path)
		print("icone %s -> %s (%s)" % [id, path, error_string(erro)])
		images.append(image)
	_save_sheet(images)
	quit()


# --- Renderização ---

## Desenha o ícone: cada pixel junta SAMPLES x SAMPLES amostras; a cobertura vira o alfa.
func _render(shape: Callable, base: Color) -> Image:
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = [Color.TRANSPARENT, base, base.darkened(DARKEN), COLOR_ACCENT]
	for y: int in SIZE:
		for x: int in SIZE:
			var sum: Color = Color(0.0, 0.0, 0.0, 0.0)
			var covered: int = 0
			for sy: int in SAMPLES:
				for sx: int in SAMPLES:
					var p: Vector2 = Vector2(float(x) + (float(sx) + 0.5) / float(SAMPLES),
							float(y) + (float(sy) + 0.5) / float(SAMPLES))
					var layer: int = int(shape.call(p))
					if layer > 0:
						var c: Color = colors[layer]
						sum += Color(c.r, c.g, c.b, 0.0)
						covered += 1
			if covered > 0:
				var n: float = float(covered)
				image.set_pixel(x, y, Color(sum.r / n, sum.g / n, sum.b / n, n / float(SAMPLES * SAMPLES)))
	return image


## Folha de contato: os 9 ícones ampliados em grade 3x3 sobre o fundo escuro dos amuletos.
func _save_sheet(images: Array[Image]) -> void:
	var cell: int = SIZE * SHEET_SCALE
	var side: int = 3 * cell + 4 * SHEET_GAP
	var sheet: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	sheet.fill(COLOR_SHEET_BG)
	for i: int in images.size():
		var big: Image = images[i].duplicate() as Image
		big.resize(cell, cell, Image.INTERPOLATE_NEAREST)
		var origin: Vector2i = Vector2i(SHEET_GAP + (i % 3) * (cell + SHEET_GAP), SHEET_GAP + (i / 3) * (cell + SHEET_GAP))
		sheet.blend_rect(big, Rect2i(0, 0, cell, cell), origin)
	var erro: Error = sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	print("folha de contato -> %s (%s)" % [SHEET_PATH, error_string(erro)])


# --- Geometria (coordenadas em px do ícone, y para baixo; ângulos em graus, sentido horário) ---

func _seg(p: Vector2, a: Vector2, b: Vector2, width: float) -> bool:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) <= width * 0.5


func _disc(p: Vector2, center: Vector2, radius: float) -> bool:
	return p.distance_to(center) <= radius


func _ring(p: Vector2, center: Vector2, radius: float, width: float) -> bool:
	return absf(p.distance_to(center) - radius) <= width * 0.5


## Arco de `a0` a `a1` graus (no sentido horário da tela, a1 > a0).
func _arc(p: Vector2, center: Vector2, radius: float, width: float, a0: float, a1: float) -> bool:
	if not _ring(p, center, radius, width):
		return false
	var angle: float = fposmod(rad_to_deg((p - center).angle()) - a0, 360.0)
	return angle <= a1 - a0


## Ponto dentro do polígono (regra par-ímpar).
func _poly(p: Vector2, points: Array[Vector2]) -> bool:
	var inside: bool = false
	var j: int = points.size() - 1
	for i: int in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[j]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside


func _polar(center: Vector2, degrees: float, radius: float) -> Vector2:
	return center + Vector2.from_angle(deg_to_rad(degrees)) * radius


# --- Os ícones ---

## Reflexos: raio com duas linhas de velocidade.
func _reflexos(p: Vector2) -> int:
	if _seg(p, Vector2(2, 21), Vector2(9, 21), 1.8) or _seg(p, Vector2(3, 26), Vector2(8, 26), 1.8):
		return 2
	var raio: Array[Vector2] = [Vector2(20, 2), Vector2(8, 17), Vector2(15, 17), Vector2(12, 30),
			Vector2(25, 13), Vector2(17, 13), Vector2(22, 2)]
	return 1 if _poly(p, raio) else 0


## Carga Rápida: projétil com anel de carga, rastro e faíscas.
func _carga_rapida(p: Vector2) -> int:
	var centro: Vector2 = Vector2(20, 16)
	if _disc(p, centro, 4.5):
		return 3
	if _arc(p, centro, 10.0, 2.4, -90.0, 180.0):
		return 1
	if _seg(p, Vector2(2, 13), Vector2(9, 13), 2.2) or _seg(p, Vector2(1, 17), Vector2(8, 17), 2.2) \
			or _seg(p, Vector2(3, 21), Vector2(9, 21), 2.2):
		return 2
	if _seg(p, Vector2(10, 7), Vector2(7, 4), 1.8) or _seg(p, Vector2(14, 5), Vector2(13, 1.5), 1.8):
		return 3
	return 0


## Pele de Ferro: peitoral de armadura com rebites.
func _pele_de_ferro(p: Vector2) -> int:
	if _seg(p, Vector2(10, 15), Vector2(16, 20), 2.0) or _seg(p, Vector2(22, 15), Vector2(16, 20), 2.0) \
			or _seg(p, Vector2(16, 20), Vector2(16, 25), 2.0):
		return 2
	if _disc(p, Vector2(11, 10), 1.3) or _disc(p, Vector2(21, 10), 1.3):
		return 2
	var peitoral: Array[Vector2] = [Vector2(6, 5), Vector2(13, 5), Vector2(16, 8.5), Vector2(19, 5), Vector2(26, 5),
			Vector2(29, 12), Vector2(24, 15), Vector2(24, 27), Vector2(8, 27), Vector2(8, 15), Vector2(3, 12)]
	return 1 if _poly(p, peitoral) else 0


## Pulso Gélido: floco de neve de seis pontas.
func _pulso_gelido(p: Vector2) -> int:
	var c: Vector2 = Vector2(16, 16)
	if _disc(p, c, 2.4):
		return 3
	for k: int in 3:
		var dir: Vector2 = Vector2.from_angle(deg_to_rad(60.0 * float(k)))
		if _seg(p, c - dir * 13.0, c + dir * 13.0, 2.2):
			return 1
		for sign_v: float in [-1.0, 1.0]:
			var out: Vector2 = dir * sign_v
			var base: Vector2 = c + out * 8.0
			for turn: float in [-0.8, 0.8]:
				if _seg(p, base, base + out.rotated(turn) * 5.0, 1.8):
					return 2
	return 0


## Mina Binária: mina com espinhos e o "01" no meio.
func _mina_binaria(p: Vector2) -> int:
	var c: Vector2 = Vector2(16, 16)
	if _ring(p, Vector2(12.6, 16), 2.5, 1.7) or _seg(p, Vector2(19.8, 12.2), Vector2(19.8, 19.8), 1.9) \
			or _seg(p, Vector2(19.8, 12.2), Vector2(17.8, 14.0), 1.7):
		return 3
	if _ring(p, c, 8.8, 2.6):
		return 1
	for k: int in 8:
		var dir: Vector2 = Vector2.from_angle(deg_to_rad(45.0 * float(k)))
		if _seg(p, c + dir * 8.8, c + dir * 13.5, 2.6):
			return 1
	return 0


## Drone Aliado: corpo central, quatro braços e quatro hélices.
func _drone_aliado(p: Vector2) -> int:
	var c: Vector2 = Vector2(16, 16)
	if _disc(p, c, 1.7):
		return 3
	if _disc(p, c, 4.2):
		return 1
	for corner: Vector2 in [Vector2(7, 7), Vector2(25, 7), Vector2(7, 25), Vector2(25, 25)]:
		if _ring(p, corner, 4.4, 1.9):
			return 1
		if _seg(p, c, corner, 2.0):
			return 2
	return 0


## Tiro em Leque: cinco linhas saindo de um ponto, em arco.
func _tiro_em_leque(p: Vector2) -> int:
	var origem: Vector2 = Vector2(16, 27)
	if _disc(p, origem, 3.2):
		return 2
	for graus: float in [-130.0, -110.0, -90.0, -70.0, -50.0]:
		var ponta: Vector2 = _polar(origem, graus, 21.0)
		if _disc(p, ponta, 2.3):
			return 3 if graus == -90.0 else 1
		if _seg(p, origem, ponta, 1.9):
			return 1
	return 0


## Máquina Enigma: engrenagem (rotor) com oito dentes.
func _maquina_enigma(p: Vector2) -> int:
	var c: Vector2 = Vector2(16, 16)
	if _disc(p, c, 1.6):
		return 3
	if _ring(p, c, 3.6, 1.8):
		return 2
	if _ring(p, c, 8.8, 3.2):
		return 1
	for k: int in 8:
		var dir: Vector2 = Vector2.from_angle(deg_to_rad(45.0 * float(k) + 22.5))
		if _seg(p, c + dir * 9.0, c + dir * 13.5, 3.8):
			return 1
	return 0


## Overclock: velocímetro com a zona vermelha no fim da escala.
func _overclock(p: Vector2) -> int:
	var c: Vector2 = Vector2(16, 17)
	if _disc(p, c, 2.8):
		return 3
	if _seg(p, c, c + Vector2(7.5, -6.5), 2.6):
		return 1
	if _arc(p, c, 11.5, 2.8, 345.0, 405.0):
		return 3
	if _arc(p, c, 11.5, 2.8, 135.0, 345.0):
		return 1
	for k: int in 5:
		var dir: Vector2 = Vector2.from_angle(deg_to_rad(135.0 + 54.0 * float(k)))
		if _seg(p, c + dir * 7.0, c + dir * 9.0, 1.5):
			return 2
	return 0
