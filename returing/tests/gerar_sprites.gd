extends SceneTree
## Gerador dos sprites pixelados dos efeitos das habilidades (mina, chama, drone). Sem suavização: cada pixel
## é uma cor da paleta, como os sprites do jogo (a chama usa a mesma escada vermelho-laranja-amarelo do `fire.png`).
## Reproduzível e sem asset de fora.
##   godot --headless --path . --script res://tests/gerar_sprites.gd
## Depois rode `godot --headless --path . --import --quit` para o Godot criar os `.import`.
## Saída em res://abilities/sprites/ (cada arquivo é uma tira de quadros lado a lado):
##   binary_mine.png      3 quadros 16x16 (parada, armada acesa, armada apagada)
##   mine_explosion.png   5 quadros 40x40
##   fire_flame.png       6 quadros 16x24 (chama do chão)
##   fire_halo.png        4 quadros 8x12 (chama pequena da espada)
##   fire_ground.png      1 quadro 30x30 (chão chamuscado)
##   ally_drone.png       2 quadros 16x16 (hélices em posições diferentes)

const OUT_DIR: String = "res://abilities/sprites/"

# Chama (mesma escada de cores do `fire.png` do jogo).
const FIRE_RED: Color = Color("#d81414")
const FIRE_ORANGE: Color = Color("#ff6a00")
const FIRE_YELLOW: Color = Color("#ffc414")
const FIRE_PALE: Color = Color("#fff4a8")
const FIRE_DARK: Color = Color("#7a0c0c")
# Mina e drone.
const OUTLINE: Color = Color("#0b0d14")
const STEEL_DARK: Color = Color("#222a38")
const STEEL: Color = Color("#3a4559")
const STEEL_LIGHT: Color = Color("#6a7a94")
const CYAN: Color = Color("#8fd0f0")
const CYAN_DIM: Color = Color("#3f7f9e")
const LED_RED: Color = Color("#ff3b2f")
const LED_DARK: Color = Color("#6a1410")
const GOLD: Color = Color("#ffd24a")
const BLADE: Color = Color("#c8d0dc")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_mine_sheet(), "binary_mine")
	_save(_explosion_sheet(), "mine_explosion")
	_save(_flame_sheet(6, 16, 24, [14, 20, 16], 2), "fire_flame")
	_save(_flame_sheet(4, 8, 12, [10, 7, 8], 1), "fire_halo")
	_save(_ground(), "fire_ground")
	_save(_drone_sheet(), "ally_drone")
	quit()


func _save(image: Image, nome: String) -> void:
	var caminho: String = ProjectSettings.globalize_path(OUT_DIR + nome + ".png")
	print("sprite %s (%dx%d) -> %s" % [nome, image.get_width(), image.get_height(), error_string(image.save_png(caminho))])


func _new(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func _put(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)


# --- Mina ---

## Três quadros de 16x16: corpo de aço com contorno, 8 espinhos e um LED no meio.
func _mine_sheet() -> Image:
	var sheet: Image = _new(48, 16)
	var leds: Array[Color] = [CYAN_DIM, LED_RED, LED_DARK]
	for frame: int in 3:
		_mine_frame(sheet, frame * 16, leds[frame], frame == 1)
	return sheet


func _mine_frame(sheet: Image, ox: int, led: Color, glow: bool) -> void:
	var c: float = 7.5
	for y: int in 16:
		for x: int in 16:
			var dx: float = float(x) - c
			var dy: float = float(y) - c
			var r: float = sqrt(dx * dx + dy * dy)
			var cor: Color = Color.TRANSPARENT
			# espinhos: quatro retos (2 px de largura) e quatro diagonais
			var reto: bool = (absf(dx) <= 1.0 and absf(dy) <= 7.5 and r > 4.5) or (absf(dy) <= 1.0 and absf(dx) <= 7.5 and r > 4.5)
			var diagonal: bool = absf(absf(dx) - absf(dy)) <= 0.9 and r > 5.0 and r <= 7.8
			if reto or diagonal:
				cor = OUTLINE if (r > 6.4) else STEEL_LIGHT
			if r <= 5.6:
				cor = OUTLINE
			if r <= 4.6:
				cor = STEEL
				if dx + dy < -2.0:
					cor = STEEL_LIGHT  # luz vindo de cima à esquerda
				elif dx + dy > 3.0:
					cor = STEEL_DARK
			if r <= 2.1:
				cor = OUTLINE
			if r <= 1.5:
				cor = led
			if glow and r <= 0.8:
				cor = FIRE_PALE
			if cor.a > 0.0:
				_put(sheet, ox + x, y, cor)
	if glow:  # brilho em cruz em volta do LED aceso
		for p: Vector2i in [Vector2i(7, 4), Vector2i(8, 4), Vector2i(7, 11), Vector2i(8, 11), Vector2i(4, 7), Vector2i(4, 8), Vector2i(11, 7), Vector2i(11, 8)]:
			_put(sheet, ox + p.x, p.y, FIRE_ORANGE)


## Cinco quadros de 40x40: anel de faíscas que se abre e esfria (amarelo, laranja, vermelho, brasas).
func _explosion_sheet() -> Image:
	var sheet: Image = _new(200, 40)
	var raios: Array[float] = [7.0, 13.0, 17.0, 19.0, 19.5]
	var espessura: Array[float] = [4.0, 3.5, 3.0, 2.0, 1.0]
	var cores: Array[Color] = [FIRE_PALE, FIRE_YELLOW, FIRE_ORANGE, FIRE_RED, FIRE_DARK]
	for frame: int in 5:
		var ox: int = frame * 40
		for y: int in 40:
			for x: int in 40:
				var dx: float = float(x) + 0.5 - 20.0
				var dy: float = float(y) + 0.5 - 20.0
				var r: float = sqrt(dx * dx + dy * dy)
				var dentro: float = raios[frame] - r
				if dentro < 0.0 or dentro > espessura[frame]:
					continue
				# anel "mordido": pixels faltando deixam a borda irregular (e some aos poucos)
				var falha: int = (x * 7 + y * 13 + frame * 5) % 5
				if falha < frame:
					continue
				var tom: int = clampi(frame + (1 if dentro > espessura[frame] * 0.6 else 0), 0, 4)
				_put(sheet, ox + x, y, cores[tom])
		# faíscas soltas fora do anel
		for i: int in 6 + frame * 2:
			var ang: float = float((i * 53 + frame * 17) % 360)
			var dist: float = raios[frame] + 1.0 + float((i * 5 + frame * 3) % 4)
			var p: Vector2 = Vector2(20.0, 20.0) + Vector2.from_angle(deg_to_rad(ang)) * dist
			_put(sheet, ox + int(p.x), int(p.y), cores[mini(frame + 1, 4)] if i % 2 == 0 else cores[mini(frame, 4)])
	return sheet


# --- Chama ---

## Tira de chamas: `picos` são as alturas dos três bicos; cada quadro desloca e balança os bicos.
func _flame_sheet(frames: int, w: int, h: int, picos: Array, brasas: int) -> Image:
	var sheet: Image = _new(frames * w, h)
	var posicoes: Array[float] = [float(w) * 0.22, float(w) * 0.5, float(w) * 0.78]
	for frame: int in frames:
		var alturas: Array[int] = []
		for cx: int in w:
			var melhor: int = 2
			for i: int in 3:
				var balanco: float = sin(float(frame) * 1.9 + float(i) * 2.3) * float(w) * 0.06
				var altura_pico: int = int(picos[(i + frame) % 3]) - (frame % 2) * (i % 2)
				var inclinacao: float = 3.0 if w >= 12 else 2.0
				var altura: int = altura_pico - int(absf(float(cx) - posicoes[i] - balanco) * inclinacao)
				melhor = maxi(melhor, altura)
			alturas.append(mini(melhor, h - 1))
		for cx: int in w:
			for yb: int in alturas[cx]:
				var profundidade: int = alturas[cx] - 1 - yb
				var lateral: bool = cx <= 1 or cx >= w - 2
				var degrau: int = 0 if profundidade <= 1 else (1 if profundidade <= 4 else (2 if profundidade <= 7 else 3))
				if lateral:
					degrau = maxi(degrau - 1, 0)
				if yb <= 1:
					degrau = maxi(degrau, 2)  # base sempre mais clara
				var tons: Array[Color] = [FIRE_RED, FIRE_ORANGE, FIRE_YELLOW, FIRE_PALE]
				_put(sheet, frame * w + cx, h - 1 - yb, tons[degrau])
		# brasas soltando da ponta nos quadros finais
		if frame >= frames / 2:
			for i: int in brasas * 3:
				var bx: int = (i * 5 + frame * 3) % w
				var by: int = maxi(h - 1 - alturas[bx] - 2 - (i * 3 + frame) % 4, 0)
				_put(sheet, frame * w + bx, by, FIRE_ORANGE if i % 2 == 0 else FIRE_RED)
	return sheet


## Chão chamuscado 30x30: disco escuro tramado (xadrez), com brasas no contorno.
func _ground() -> Image:
	var image: Image = _new(30, 30)
	for y: int in 30:
		for x: int in 30:
			var dx: float = float(x) + 0.5 - 15.0
			var dy: float = float(y) + 0.5 - 15.0
			var r: float = sqrt(dx * dx + dy * dy)
			if r > 14.5:
				continue
			var xadrez: bool = (x + y) % 2 == 0
			if r > 12.5:
				if xadrez:
					_put(image, x, y, FIRE_ORANGE if (x * 3 + y) % 4 == 0 else FIRE_RED)
			elif r > 8.5:
				if xadrez:
					_put(image, x, y, Color(FIRE_DARK, 0.7))
			else:
				_put(image, x, y, Color(FIRE_DARK, 0.45 if xadrez else 0.3))
	return image


# --- Drone ---

## Dois quadros de 16x16: corpo de aço com contorno, LED dourado/ciano e quatro hélices que alternam
## entre traço horizontal e vertical (parece girar).
func _drone_sheet() -> Image:
	var sheet: Image = _new(32, 16)
	for frame: int in 2:
		var ox: int = frame * 16
		var cantos: Array[Vector2i] = [Vector2i(2, 2), Vector2i(13, 2), Vector2i(2, 13), Vector2i(13, 13)]
		for canto: Vector2i in cantos:
			var sx: int = 1 if canto.x < 8 else -1
			var sy: int = 1 if canto.y < 8 else -1
			# braço em diagonal até o corpo (contorno + miolo)
			for k: int in range(1, 4):
				_put(sheet, ox + canto.x + sx * k, canto.y + sy * k, STEEL_LIGHT if k < 3 else OUTLINE)
			# hélice: sombra escura de 1 px e traço claro por cima
			for k: int in range(-3, 4):
				var bx: int = canto.x + (k if frame == 0 else 0)
				var by: int = canto.y + (k if frame == 1 else 0)
				_put(sheet, ox + bx + (1 if frame == 1 else 0), by + (1 if frame == 0 else 0), OUTLINE)
			for k: int in range(-3, 4):
				var bx2: int = canto.x + (k if frame == 0 else 0)
				var by2: int = canto.y + (k if frame == 1 else 0)
				_put(sheet, ox + bx2, by2, BLADE)
			_put(sheet, ox + canto.x, canto.y, STEEL)
		# corpo 6x6 com contorno e luz de cima à esquerda
		for y: int in range(5, 11):
			for x: int in range(5, 11):
				var borda: bool = x == 5 or x == 10 or y == 5 or y == 10
				var cor: Color = OUTLINE if borda else (STEEL_LIGHT if (x + y) < 13 else STEEL)
				_put(sheet, ox + x, y, cor)
		_put(sheet, ox + 7, 7, GOLD)
		_put(sheet, ox + 8, 7, GOLD)
		_put(sheet, ox + 7, 8, CYAN)
		_put(sheet, ox + 8, 8, CYAN)
	return sheet
