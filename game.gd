extends Node3D
# All geometry is original and generated locally. No addons or downloads.
var head: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var floors: Array[Node3D] = []
var body: Array[Node3D] = []
var trail: Array[Vector3] = []
var gems: Array[Node3D] = []
var hazards: Array[Node3D] = []
var hud: Label
var menu: PanelContainer
var title: Label
var info: Label
var play_button: Button
var level := 0
var score := 0
var lives := 3
var energy := 100.0
var yaw := 0.0
var orbit := 0.0
var pitch := 0.4
var clock := 0.0
var invulnerable := 0.0
var playing := false
var started := false
var best := 0
var holes := [Vector2(-4, -2), Vector2(4, 4), Vector2(0, -6)]
var palette := [Color("#29bfa8"), Color("#ffcb59"), Color("#a18afa"), Color("#ef8ba7")]
var sound: AudioStreamPlayer
var muted := false

func material(color: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.4
	return m

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = mat
	parent.add_child(n)
	n.position = pos
	return n

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var s := BoxMesh.new()
	s.size = size
	return mesh(parent, s, pos, mat)

func ball(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radial_segments = 16
	s.rings = 8
	var n := mesh(parent, s, pos, mat)
	n.scale = size
	return n

func label3(parent: Node3D, caption: String, pos: Vector3):
	var l := Label3D.new()
	l.text = caption
	l.font_size = 52
	l.pixel_size = 0.012
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	l.position = pos

func _ready():
	var config := ConfigFile.new()
	if config.load("user://save.cfg") == OK:
		best = config.get_value("game", "best", 0)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#142235")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c1e6f5")
	env.ambient_light_energy = 0.65
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("#fff1cf")
	sun.light_energy = 1.25
	add_child(sun)
	build_arena()
	build_snake()
	camera = Camera3D.new()
	camera.fov = 68
	camera.far = 180
	add_child(camera)
	sound = AudioStreamPlayer.new()
	add_child(sound)
	build_ui()
	reset_run()
	playing = false
	started = false
	menu.show()
	title.text = "C O I L"
	info.text = "НЕБЕСНЫЕ САДЫ\n\nЧетыре этажа. Одна маленькая змея.\nСобери 24 кристалла и вернись к маяку наверху.\n\nW/S — движение • A/D — поворот • мышь — обзор\nShift — рывок • E — лифт • Esc — пауза\nОтверстия сбрасывают на этаж ниже. Красные шары опасны."

func build_arena():
	for f in range(4):
		var root := Node3D.new()
		add_child(root)
		root.position.y = f * 5.0
		floors.append(root)
		var mat := material(palette[f])
		var dark := material(palette[f].darkened(0.25))
		for x in range(-5, 6):
			for z in range(-5, 6):
				var p := Vector2(x * 2, z * 2)
				if p in holes:
					continue
				box(root, Vector3(p.x, -0.2, p.y), Vector3(1.96, 0.4, 1.96), mat if (x+z)%2 == 0 else dark)
		for x in [-10.7, 10.7]:
			box(root, Vector3(x, 0.35, 0), Vector3(0.12, 0.7, 21.5), material(Color("#dcebee")))
		for z in [-10.7, 10.7]:
			box(root, Vector3(0, 0.35, z), Vector3(21.5, 0.7, 0.12), material(Color("#dcebee")))
		for x in [-9, 9]:
			for z in [-9, 9]:
				box(root, Vector3(x, -2.5, z), Vector3(0.25, 5, 0.25), material(Color("#364b65")))
		for p in holes:
			label3(root, "↓", Vector3(p.x, 0.4, p.y))
		box(root, Vector3(8, 0.04, -8), Vector3(2, 0.12, 2), material(Color("#82f7de"), true))
		label3(root, "E  ↑  ЛИФТ" if f < 3 else "МАЯК • 24 ◆", Vector3(8, 1.5, -8))
		for j in range(8):
			var gem := Node3D.new()
			root.add_child(gem)
			gem.position = Vector3(-7 + (j%4)*4, 0.9, -4 + (j/4)*9)
			var shape := CylinderMesh.new()
			shape.top_radius = 0
			shape.bottom_radius = 0.4
			shape.height = 0.8
			shape.radial_segments = 5
			mesh(gem, shape, Vector3.ZERO, material(Color("#fff2a1"), true))
			gem.set_meta("floor", f)
			gems.append(gem)
		var hazard := ball(root, Vector3(0,0.6,0), Vector3(1.3,0.65,1.3), material(Color("#ff526d"), true))
		hazard.set_meta("floor", f)
		hazards.append(hazard)

func build_snake():
	head = Node3D.new()
	add_child(head)
	var skin := material(Color("#a7df83"))
	ball(head, Vector3.ZERO, Vector3(1.05,0.48,1.3), skin)
	ball(head, Vector3(0,-0.06,-0.42), Vector3(0.85,0.3,0.65), skin)
	for side in [-1,1]:
		ball(head, Vector3(side*0.4,0.13,-0.35), Vector3(0.25,0.2,0.25), material(Color("#f4b92e")))
		ball(head, Vector3(side*0.48,0.14,-0.4), Vector3(0.06,0.16,0.13), material(Color("#19222b")))
	for i in range(22):
		var segment := Node3D.new()
		add_child(segment)
		var taper := 1.0 - float(i)/27.0
		ball(segment, Vector3.ZERO, Vector3(0.88,0.45,0.74)*taper, skin)
		ball(segment, Vector3(0,0.2*taper,0), Vector3(0.65,0.16,0.48)*taper, material(Color("#bdeb96")))
		body.append(segment)

func build_ui():
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(28,20)
	hud.add_theme_font_size_override("font_size",22)
	layer.add_child(hud)
	menu = PanelContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-290,-285)
	menu.size = Vector2(580,570)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101e30")
	style.corner_radius_top_left = 24
	style.corner_radius_bottom_right = 24
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	menu.add_theme_stylebox_override("panel",style)
	layer.add_child(menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	menu.add_child(column)
	title = Label.new()
	title.add_theme_font_size_override("font_size",52)
	title.modulate = Color("#bdeb96")
	column.add_child(title)
	info = Label.new()
	info.add_theme_font_size_override("font_size",16)
	column.add_child(info)
	play_button = Button.new()
	play_button.text = "ИГРАТЬ  →"
	play_button.custom_minimum_size.y = 48
	play_button.pressed.connect(resume_game)
	column.add_child(play_button)
	var restart := Button.new()
	restart.text = "Новый забег"
	restart.pressed.connect(func(): reset_run(); resume_game())
	column.add_child(restart)
	var quality := CheckButton.new()
	quality.text = "Красивые тени (для компьютера помощнее)"
	quality.toggled.connect(func(on): sun.shadow_enabled = on)
	column.add_child(quality)
	var audio_toggle := CheckButton.new()
	audio_toggle.text = "Выключить звуки"
	audio_toggle.toggled.connect(func(on): muted = on)
	column.add_child(audio_toggle)

func reset_run():
	level = 0
	score = 0
	lives = 3
	energy = 100
	yaw = 0
	head.position = Vector3(0,0.5,8)
	trail.clear()
	for i in range(400):
		trail.append(head.position + Vector3(0,0,i*0.06))
	for gem in gems:
		gem.show()
	invulnerable = 2

func resume_game():
	if not started:
		reset_run()
	playing = true
	started = true
	menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if event is InputEventMouseMotion and playing:
		orbit -= event.relative.x * 0.003
		pitch = clampf(pitch + event.relative.y*0.002,0.15,0.8)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and started:
			playing = not playing
			menu.visible = not playing
			title.text = "ПАУЗА"
			info.text = "Выдохни. Сады подождут.\nРекорд: %d ◆" % best
			play_button.text = "ПРОДОЛЖИТЬ →"
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_E and playing and Vector2(head.position.x-8,head.position.z+8).length() < 1.8:
			if level < 3:
				change_floor(level+1)
				tone(660)
			elif score >= 24:
				finish(true)

func change_floor(next: int):
	level = next
	head.position.y = level*5 + 0.5
	for i in range(trail.size()):
		trail[i].y = head.position.y
	invulnerable = 1.5

func _physics_process(delta):
	clock += delta
	if playing:
		invulnerable = maxf(0, invulnerable-delta)
		var turn := float(Input.is_physical_key_pressed(KEY_A))-float(Input.is_physical_key_pressed(KEY_D))
		yaw += turn*2.5*delta
		var moving := float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S))
		var boost := Input.is_physical_key_pressed(KEY_SHIFT) and energy > 2 and moving != 0
		energy = clampf(energy + (-32 if boost else 18)*delta,0,100)
		head.position += Vector3(-sin(yaw),0,-cos(yaw))*moving*(7.0 if boost else 3.5)*delta
		head.position.x = clampf(head.position.x,-10,10)
		head.position.z = clampf(head.position.z,-10,10)
		head.rotation.y = yaw
		if head.position.distance_to(trail[0]) > 0.055:
			trail.push_front(head.position)
			trail.resize(400)
		for p in holes:
			if Vector2(head.position.x,head.position.z).distance_to(p) < 0.72 and invulnerable <= 0:
				if level > 0:
					change_floor(level-1)
					tone(180)
				else:
					damage()
		for gem in gems:
			if gem.visible and gem.get_meta("floor") == level and head.position.distance_to(gem.global_position) < 1.0:
				gem.hide()
				score += 1
				energy = minf(100,energy+15)
				tone(450+score*18)
		for h in hazards:
			if h.get_meta("floor") == level and h.global_position.distance_to(head.position) < 1.1:
				damage()
	for i in range(body.size()):
		body[i].position = trail[mini((i+1)*8,trail.size()-1)]
		body[i].visible = i < 10+score/2
	for f in range(4):
		floors[f].visible = f <= level if playing else true
	for h in hazards:
		h.position.x = sin(clock*0.65+float(h.get_meta("floor")))*7
		h.position.z = cos(clock*0.9)*2
	for gem in gems:
		gem.rotation.y += delta
	head.visible = invulnerable <= 0 or sin(clock*22)>-0.3
	if playing:
		var angle := yaw+orbit
		var target := head.position + Vector3(sin(angle)*5,2.0+pitch*3,cos(angle)*5)
		camera.position = camera.position.lerp(target,1-exp(-7*delta))
		camera.look_at(head.position+Vector3(0,0.3,0))
	else:
		camera.position = Vector3(sin(clock*0.1)*32,27,cos(clock*0.1)*32)
		camera.look_at(Vector3(0,7,0))
	hud.text = "COIL   /   ЭТАЖ %d из 4     ◆ %d / 24     ♥ %d     РЫВОК %d%%\nWASD • Shift • E: лифт в углу [8, −8] • Esc" % [level+1,score,lives,int(energy)]

func damage():
	if invulnerable > 0:
		return
	lives -= 1
	tone(100)
	if lives <= 0:
		finish(false)
	else:
		head.position = Vector3(0,level*5+0.5,8)
		change_floor(level)
		for i in range(trail.size()):
			trail[i] = head.position+Vector3(0,0,i*0.06)

func finish(won: bool):
	playing = false
	started = false
	best = maxi(best,score)
	var config := ConfigFile.new()
	config.set_value("game","best",best)
	config.save("user://save.cfg")
	menu.show()
	title.text = "САДЫ ТВОИ!" if won else "ЕЩЁ ВИТОК?"
	info.text = "Собрано: %d ◆   •   Рекорд: %d ◆\nНовый забег — новая попытка покорить сады." % [score,best]
	play_button.text = "НОВЫЙ ЗАБЕГ →"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func replay():
	reset_run()
	resume_game()

func tone(frequency: float):
	if muted:
		return
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(4410)
	for i in range(2205):
		var value := int(sin(TAU*frequency*i/22050.0)*6000*(1.0-i/2205.0))
		data.encode_s16(i*2,value)
	wave.data = data
	sound.stream = wave
	sound.play()
