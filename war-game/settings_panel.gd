extends Control
## Вікно «Налаштування»: основні, керування, чутливість, графіка та FPS, звук, мікрофон, HUD.
## Відкривається з головного меню і під час бою (поверх гри, без паузи).

const UI = preload("res://uikit.gd")
const Settings = preload("res://settings.gd")

const TABS := [["main", "Основні"], ["controls", "Керування"], ["sens", "Чутливість"], ["graphics", "Графіка та FPS"],
	["audio", "Звук"], ["mic", "Мікрофон"], ["hud", "Налаштування HUD"]]

var main
var tab := "main"
var content: VBoxContainer
var tab_btns := {}
var in_game := false


func setup(m) -> void:
	main = m
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := UI.panel()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_top = 30
	root.offset_right = -40
	root.offset_bottom = -30
	add_child(root)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	root.add_child(hb)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 8)
	hb.add_child(left)
	left.add_child(UI.title("НАЛАШТУВАННЯ", 28))
	for t in TABS:
		var b := UI.button(t[1], 20, 52)
		b.toggle_mode = true
		b.pressed.connect(_set_tab.bind(t[0]))
		left.add_child(b)
		tab_btns[t[0]] = b
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	var close := UI.button("Закрити", 22, 56)
	close.pressed.connect(close_panel)
	left.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	hide()


func open(game: bool) -> void:
	if visible:
		return
	in_game = game
	_set_tab(tab)
	UI.fade_in(self)


func close_panel() -> void:
	if not visible:
		return
	Settings.save()
	UI.fade_out(self)
	main.on_settings_closed()


func _set_tab(t: String) -> void:
	tab = t
	for k in tab_btns:
		tab_btns[k].button_pressed = k == t
	for c in content.get_children():
		c.queue_free()
	match t:
		"main": _tab_main()
		"controls": _tab_controls()
		"sens": _tab_sens()
		"graphics": _tab_graphics()
		"audio": _tab_audio()
		"mic": _tab_mic()
		"hud": _tab_hud()


# ---------------------------------------------------------------- елементи

func _row(text: String, ctrl: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	var l := UI.label(text, 20)
	l.custom_minimum_size = Vector2(300, 0)
	hb.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(ctrl)
	content.add_child(hb)


func _slider_row(text: String, sec: String, key: String, minv: float, maxv: float, step: float, fmt: String = "%d%%", k: float = 100.0) -> void:
	var hb := HBoxContainer.new()
	var s := UI.slider(minv, maxv, step, float(Settings.value(sec, key)))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.label(fmt % (s.value * k), 20, UI.ACCENT)
	v.custom_minimum_size = Vector2(80, 0)
	s.value_changed.connect(func(x: float):
		Settings.set_value(sec, key, x, false)
		v.text = fmt % (x * k)
		Settings.apply(get_tree()))
	hb.add_child(s)
	hb.add_child(v)
	_row(text, hb)


func _choice_row(text: String, sec: String, key: String, options: Array, values: Array) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var cur = Settings.value(sec, key)
	var btns: Array = []
	for i in options.size():
		var b := UI.button(String(options[i]), 18, 48)
		b.toggle_mode = true
		b.button_pressed = values[i] == cur
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.append(b)
		hb.add_child(b)
	for i in btns.size():
		btns[i].pressed.connect(func():
			Settings.set_value(sec, key, values[i])
			for j in btns.size():
				btns[j].button_pressed = j == i
			Settings.apply(get_tree()))
	_row(text, hb)


func _toggle_row(text: String, sec: String, key: String) -> void:
	_choice_row(text, sec, key, ["Вимк.", "Увімк."], [0, 1])


func _note(text: String) -> void:
	var l := UI.label(text, 17, UI.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(l)


# ---------------------------------------------------------------- вкладки

func _tab_main() -> void:
	content.add_child(UI.title("Основні", 26))
	var nick := UI.label(String(Settings.value("main", "nick", "—")), 22, UI.ACCENT)
	_row("Позивний (назавжди)", nick)
	var addr := LineEdit.new()
	addr.text = String(Settings.value("main", "addr", main.DEFAULT_ADDR))
	addr.add_theme_font_size_override("font_size", 20)
	addr.custom_minimum_size = Vector2(0, 48)
	addr.text_submitted.connect(func(t: String): Settings.set_value("main", "addr", t.strip_edges()))
	addr.focus_exited.connect(func(): Settings.set_value("main", "addr", addr.text.strip_edges()))
	_row("Адреса сервера", addr)
	if in_game:
		var leave := UI.button("Вийти з бою в меню", 22, 58)
		leave.pressed.connect(func():
			close_panel()
			main.leave_match())
		content.add_child(leave)
	else:
		var rc := UI.button("Перепідключитися до сервера", 20, 54)
		rc.pressed.connect(func(): main.menu_connect(true))
		content.add_child(rc)


func _tab_controls() -> void:
	content.add_child(UI.title("Керування", 26))
	_toggle_row("Інверсія огляду по вертикалі", "controls", "invert_y")
	_toggle_row("Біг при відведенні джойстика вперед", "controls", "auto_sprint")
	_choice_row("Профіль розкладки HUD", "controls", "hud_profile", ["1", "2", "3"], [1, 2, 3])
	var ed := UI.button("Відкрити редактор HUD", 22, 58)
	ed.pressed.connect(_open_editor)
	content.add_child(ed)
	_note("Клавіатура на ПК: WASD — рух, миша — огляд, Пробіл — стрибок, C — присісти, Z — лягти, 1/3 — нахили, Shift — біг, R — перезарядка, G — граната, H — аптечка, Q — зброя, E — дрон, V — плече камери.")


func _tab_sens() -> void:
	content.add_child(UI.title("Чутливість", 26))
	_slider_row("Камера", "controls", "sens", 0.2, 3.0, 0.05)
	_slider_row("Приціл", "controls", "aim_sens", 0.2, 3.0, 0.05)
	_slider_row("FPV-дрон", "controls", "drone_sens", 0.2, 3.0, 0.05)


func _tab_graphics() -> void:
	content.add_child(UI.title("Графіка та FPS", 26))
	_choice_row("Якість графіки", "graphics", "quality", ["Низька", "Середня", "Висока"], [0, 1, 2])
	_choice_row("Якість текстур", "graphics", "textures", ["Низька", "Середня", "Висока"], [0, 1, 2])
	_choice_row("Частота кадрів", "graphics", "fps", ["30", "60", "90", "Без обмеж."], [30, 60, 90, 0])
	_toggle_row("Тіні", "graphics", "shadows")
	_slider_row("Дальність трави", "graphics", "grass", 0.0, 1.5, 0.05)
	_note("Низька якість зменшує роздільність 3D і деталізацію — для слабших телефонів.")


func _tab_audio() -> void:
	content.add_child(UI.title("Звук", 26))
	_slider_row("Загальна гучність", "audio", "master", 0.0, 1.0, 0.01)
	_slider_row("Музика", "audio", "music", 0.0, 1.0, 0.01)
	_slider_row("Звуки бою", "audio", "sfx", 0.0, 1.0, 0.01)


func _tab_mic() -> void:
	content.add_child(UI.title("Мікрофон", 26))
	_toggle_row("Мікрофон", "mic", "enabled")
	_toggle_row("Говорити лише при натисканні", "mic", "push_to_talk")
	_slider_row("Гучність мікрофона", "mic", "volume", 0.0, 1.0, 0.01)
	var devs := AudioServer.get_input_device_list()
	var names: Array = []
	for d in devs:
		names.append(String(d))
	if names.is_empty():
		names = ["Default"]
	_choice_row("Пристрій", "mic", "device", names.slice(0, 3), names.slice(0, 3))
	_note("Голосовий зв'язок у команді ще в розробці: ці налаштування збережуться і запрацюють, коли його буде додано.")


func _tab_hud() -> void:
	content.add_child(UI.title("Налаштування HUD", 26))
	_note("Розставте кнопки, джойстик, слоти і карту там, де вам зручно. Для кожного елемента — розмір, прозорість, показ або приховування.")
	_choice_row("Активний профіль", "controls", "hud_profile", ["1", "2", "3"], [1, 2, 3])
	var ed := UI.action_button("ВІДКРИТИ РЕДАКТОР HUD", 24)
	ed.pressed.connect(_open_editor)
	content.add_child(ed)


func _open_editor() -> void:
	Settings.save()
	hide()
	main.open_hud_editor()
