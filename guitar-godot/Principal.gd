extends Node2D
# Juego de ritmo estilo Guitar Hero - Godot 4.x
# Teclas: W A S D | ENTER o ESPACIO para empezar

const CARRILES := 4
const TECLAS = [KEY_W, KEY_A, KEY_S, KEY_D]
const LETRAS = ["W", "A", "S", "D"]
const RUTAS_NOTAS = [
	"res://Images/Nota (1).png",
	"res://Images/Nota (2).png",
	"res://Images/Nota (3).png",
	"res://Images/Nota (4).png",
]
const RUTA_LOGO := "res://Images/Logo.png"
const COLORES = [
	Color(0.95, 0.3, 0.35),
	Color(0.95, 0.8, 0.25),
	Color(0.3, 0.85, 0.45),
	Color(0.3, 0.6, 0.95),
]

const ANCHO_CARRIL := 110.0
const TAMANO_NOTA := 80.0
const VELOCIDAD := 500.0      # píxeles por segundo
const BPM := 120.0
const DURACION := 60.0        # segundos de canción
const VENTANA_PERFECTO := 0.07
const VENTANA_BIEN := 0.12
const VENTANA_REGULAR := 0.18

var ancho: float
var alto: float
var linea_y: float
var x_inicio: float

var texturas_notas: Array = []
var logo: Sprite2D
var contenedor_notas: Node2D
var lbl_puntaje: Label
var lbl_combo: Label
var lbl_juicio: Label
var lbl_mensaje: Label
var sonido_acierto: AudioStreamPlayer
var sonido_fallo: AudioStreamPlayer

var estado := "menu"   # menu, jugando, fin
var tiempo := 0.0
var partitura: Array = []
var indice := 0
var activas: Array = []
var presionado := [false, false, false, false]

var puntaje := 0
var combo := 0
var combo_max := 0
var aciertos := 0
var total := 0
var tiempo_juicio := 0.0


func _ready() -> void:
	var tam := get_viewport_rect().size
	ancho = tam.x
	alto = tam.y
	linea_y = alto - 120.0
	x_inicio = (ancho - CARRILES * ANCHO_CARRIL) / 2.0

	for ruta in RUTAS_NOTAS:
		texturas_notas.append(load(ruta))

	contenedor_notas = Node2D.new()
	add_child(contenedor_notas)

	logo = Sprite2D.new()
	logo.texture = load(RUTA_LOGO)
	var f: float = 360.0 / float(logo.texture.get_width())
	logo.scale = Vector2(f, f)
	logo.position = Vector2(ancho / 2.0, 150.0)
	add_child(logo)

	var ui := CanvasLayer.new()
	add_child(ui)
	lbl_puntaje = crear_label(ui, Vector2(20, 15), Vector2(400, 40), 30, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_combo = crear_label(ui, Vector2(ancho - 420, 15), Vector2(400, 40), 30, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_juicio = crear_label(ui, Vector2(0, alto / 2.0 - 40), Vector2(ancho, 60), 44, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_mensaje = crear_label(ui, Vector2(0, alto / 2.0 - 20), Vector2(ancho, 300), 34, HORIZONTAL_ALIGNMENT_CENTER)

	sonido_acierto = AudioStreamPlayer.new()
	sonido_acierto.stream = crear_beep(880.0, 0.08)
	add_child(sonido_acierto)
	sonido_fallo = AudioStreamPlayer.new()
	sonido_fallo.stream = crear_beep(140.0, 0.15)
	add_child(sonido_fallo)

	mostrar_menu()


func crear_label(padre: Node, pos: Vector2, tam: Vector2, tamano_fuente: int, alineacion: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = tam
	l.horizontal_alignment = alineacion
	l.add_theme_font_size_override("font_size", tamano_fuente)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	padre.add_child(l)
	return l


func crear_beep(frecuencia: float, duracion: float) -> AudioStreamWAV:
	var tasa := 44100
	var n := int(tasa * duracion)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	for i in n:
		var envolvente := 1.0 - float(i) / float(n)
		var v := int(sin(TAU * frecuencia * float(i) / float(tasa)) * envolvente * 0.5 * 32767.0)
		datos.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = tasa
	s.stereo = false
	s.data = datos
	return s


func mostrar_menu() -> void:
	estado = "menu"
	logo.visible = true
	lbl_juicio.text = ""
	lbl_puntaje.text = ""
	lbl_combo.text = ""
	lbl_mensaje.position.y = 300.0
	lbl_mensaje.text = "Pulsa ENTER para empezar\n\nTeclas:  W   A   S   D"


func generar_partitura() -> void:
	partitura.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var paso := 60.0 / BPM / 2.0
	var t := 2.5
	var i := 0
	var ultimo := -1
	while t < DURACION:
		var prob := 0.7 if i % 2 == 0 else 0.15
		if rng.randf() < prob:
			var carril := rng.randi_range(0, CARRILES - 1)
			if carril == ultimo and rng.randf() < 0.5:
				carril = (carril + 1 + rng.randi_range(0, CARRILES - 2)) % CARRILES
			partitura.append({"tiempo": t, "carril": carril})
			ultimo = carril
		t += paso
		i += 1


func iniciar() -> void:
	for n in activas:
		n.sprite.queue_free()
	activas.clear()
	generar_partitura()
	puntaje = 0
	combo = 0
	combo_max = 0
	aciertos = 0
	total = partitura.size()
	tiempo = 0.0
	indice = 0
	estado = "jugando"
	logo.visible = false
	lbl_mensaje.text = ""
	lbl_juicio.text = ""
	actualizar_hud()


func terminar() -> void:
	estado = "fin"
	var precision := 0.0
	if total > 0:
		precision = float(aciertos) * 100.0 / float(total)
	lbl_juicio.text = ""
	lbl_mensaje.position.y = 200.0
	lbl_mensaje.text = "¡FIN!\n\nPuntaje: %d\nPrecisión: %.1f%%\nMejor combo: %d\n\nENTER para jugar de nuevo" % [puntaje, precision, combo_max]


func centro_x(carril: int) -> float:
	return x_inicio + (carril + 0.5) * ANCHO_CARRIL


func crear_nota(datos: Dictionary) -> void:
	var sp := Sprite2D.new()
	var tex: Texture2D = texturas_notas[datos.carril]
	sp.texture = tex
	var f: float = TAMANO_NOTA / maxf(float(tex.get_width()), float(tex.get_height()))
	sp.scale = Vector2(f, f)
	sp.position = Vector2(centro_x(datos.carril), -100.0)
	contenedor_notas.add_child(sp)
	activas.append({"tiempo": datos.tiempo, "carril": datos.carril, "sprite": sp})


func _process(delta: float) -> void:
	for i in CARRILES:
		presionado[i] = Input.is_physical_key_pressed(TECLAS[i])

	if tiempo_juicio > 0.0:
		tiempo_juicio -= delta
		lbl_juicio.modulate.a = clampf(tiempo_juicio / 0.6, 0.0, 1.0)

	if estado == "jugando":
		tiempo += delta

		var tiempo_viaje := (linea_y + 100.0) / VELOCIDAD
		while indice < partitura.size() and partitura[indice].tiempo - tiempo <= tiempo_viaje:
			crear_nota(partitura[indice])
			indice += 1

		for n in activas:
			n.sprite.position.y = linea_y - (n.tiempo - tiempo) * VELOCIDAD

		for n in activas.duplicate():
			if tiempo - n.tiempo > VENTANA_REGULAR:
				n.sprite.queue_free()
				activas.erase(n)
				fallar("¡FALLASTE!")

		if indice >= partitura.size() and activas.is_empty():
			terminar()

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if estado != "jugando":
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
				iniciar()
		else:
			for i in CARRILES:
				if event.physical_keycode == TECLAS[i]:
					golpear(i)


func golpear(carril: int) -> void:
	var objetivo = null
	for n in activas:
		if n.carril == carril and absf(n.tiempo - tiempo) <= VENTANA_REGULAR:
			objetivo = n
			break

	if objetivo == null:
		fallar("¡FALLASTE!")
		return

	var dt: float = absf(objetivo.tiempo - tiempo)
	var texto := "REGULAR"
	var base := 20
	var color := Color(0.9, 0.9, 0.9)
	if dt <= VENTANA_PERFECTO:
		texto = "¡PERFECTO!"
		base = 100
		color = Color(1.0, 0.9, 0.2)
	elif dt <= VENTANA_BIEN:
		texto = "¡BIEN!"
		base = 50
		color = Color(0.4, 1.0, 0.5)

	objetivo.sprite.queue_free()
	activas.erase(objetivo)

	combo += 1
	combo_max = maxi(combo_max, combo)
	aciertos += 1
	var multiplicador := 1 + mini(int(combo * 0.1), 3)
	puntaje += base * multiplicador
	mostrar_juicio(texto, color)
	sonido_acierto.play()
	actualizar_hud()


func fallar(texto: String) -> void:
	combo = 0
	mostrar_juicio(texto, Color(1.0, 0.3, 0.3))
	sonido_fallo.play()
	actualizar_hud()


func mostrar_juicio(texto: String, color: Color) -> void:
	lbl_juicio.text = texto
	lbl_juicio.add_theme_color_override("font_color", color)
	tiempo_juicio = 0.6
	lbl_juicio.modulate.a = 1.0


func actualizar_hud() -> void:
	lbl_puntaje.text = "Puntaje: %d" % puntaje
	var multiplicador := 1 + mini(int(combo * 0.1), 3)
	lbl_combo.text = "Combo: %d  (x%d)" % [combo, multiplicador]


func _draw() -> void:
	draw_rect(Rect2(0, 0, ancho, alto), Color(0.07, 0.05, 0.13))
	var fuente := ThemeDB.fallback_font
	for i in CARRILES:
		var x := x_inicio + i * ANCHO_CARRIL
		var fondo := Color(0.12, 0.1, 0.2)
		if presionado[i]:
			fondo = COLORES[i] * Color(1, 1, 1, 0.35) + Color(0.12, 0.1, 0.2, 0.65)
		draw_rect(Rect2(x, 0, ANCHO_CARRIL, alto), fondo)
		draw_line(Vector2(x, 0), Vector2(x, alto), Color(1, 1, 1, 0.15), 2.0)
		var centro := Vector2(centro_x(i), linea_y)
		draw_arc(centro, TAMANO_NOTA * 0.55, 0.0, TAU, 40, COLORES[i], 4.0)
		draw_string(fuente, Vector2(x, linea_y + 85.0), LETRAS[i], HORIZONTAL_ALIGNMENT_CENTER, ANCHO_CARRIL, 28, COLORES[i])
	var x_fin := x_inicio + CARRILES * ANCHO_CARRIL
	draw_line(Vector2(x_fin, 0), Vector2(x_fin, alto), Color(1, 1, 1, 0.15), 2.0)
	draw_line(Vector2(x_inicio, linea_y), Vector2(x_fin, linea_y), Color(1, 1, 1, 0.5), 3.0)
