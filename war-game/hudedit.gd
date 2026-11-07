extends Control
## Редактор HUD (як у PUBG): перетягування елементів пальцем, розмір, прозорість,
## показ/приховування, скидання. Зберегти / Скасувати / Скинути / Перевірити HUD.
## Три профілі розкладки, зберігаються між запусками (user://hud.cfg).

const UI = preload("res://uikit.gd")
const Settings = preload("res://settings.gd")

var main
var touch
var backup := {}
var profile := 1
var panel: PanelContainer
var bottom: HBoxContainer
var name_lbl: Label
var size_s: HSlider
var alpha_s: HSlider
var size_v: Label
var alpha_v: Label
var vis_b: Button
var prof_btns: Array = []
var test_btn: Button
var testing := false
var _syncing := false


func setup(m, t) -> void:
	main = m
	touch = t
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch.edit_selected.connect(_on_selected)

	panel = UI.panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = 8
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	top.add_child(UI.label("Профіль:", 18, UI.DIM))
	for i in 3:
		var b := UI.button(str(i + 1), 18, 40)
		b.custom_minimum_size = Vector2(52, 40)
		b.toggle_mode = true
		b.pressed.connect(_set_profile.bind(i + 1))
		top.add_child(b)
		prof_btns.append(b)
	name_lbl = UI.label("Торкніться елемента, щоб змінити його", 18, UI.ACCENT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(name_lbl)

	var r1 := HBoxContainer.new()
	v.add_child(r1)
	r1.add_child(_fixed(UI.label("Розмір", 17, UI.TEXT), 110))
	size_s = UI.slider(0.5, 2.0, 0.05, 1.0)
	size_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_s.value_changed.connect(_on_size)
	r1.add_child(size_s)
	size_v = _fixed(UI.label("100%", 17, UI.ACCENT), 70)
	r1.add_child(size_v)
	var r2 := HBoxContainer.new()
	v.add_child(r2)
	r2.add_child(_fixed(UI.label("Прозорість", 17, UI.TEXT), 110))
	alpha_s = UI.slider(0.0, 1.0, 0.01, 1.0)
	alpha_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alpha_s.value_changed.connect(_on_alpha)
	r2.add_child(alpha_s)
	alpha_v = _fixed(UI.label("100%", 17, UI.ACCENT), 70)
	r2.add_child(alpha_v)
	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 8)
	v.add_child(r3)
	vis_b = UI.button("Сховати", 17, 42)
	vis_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vis_b.pressed.connect(_toggle_vis)
	r3.add_child(vis_b)
	var re := UI.button("Скинути елемент", 17, 42)
	re.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	re.pressed.connect(_reset_el)
	r3.add_child(re)

	var mv := UI.button("Панель ↕", 17, 42)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.pressed.connect(_move_panel)
	r3.add_child(mv)
	bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	v.add_child(bottom)
	for d in [["Зберегти", _save], ["Скасувати", _cancel], ["Скинути", _reset_all], ["Перевірити HUD", _test]]:
		var b: Button = UI.action_button(String(d[0]), 18) if d[0] == "Зберегти" else UI.button(String(d[0]), 18, 50)
		b.custom_minimum_size = Vector2(0, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(d[1])
		bottom.add_child(b)
	test_btn = UI.button("Повернутися до редагування", 18, 50)
	test_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	test_btn.offset_left = -190
	test_btn.offset_right = 190
	test_btn.offset_top = 8
	test_btn.offset_bottom = 58
	test_btn.pressed.connect(_end_test)
	add_child(test_btn)
	test_btn.hide()
	hide()


func _fixed(c: Control, w: float) -> Control:
	c.custom_minimum_size = Vector2(w, 0)
	return c


func open() -> void:
	if visible:
		return
	profile = int(Settings.value("controls", "hud_profile", 1))
	touch.load_layout(profile)
	backup = touch.layout.duplicate(true)
	touch.edit_sel = ""
	touch.edit_mode = true
	touch.reset_input()
	touch.show()
	testing = false
	panel.show()
	test_btn.hide()
	_sync_profiles()
	_on_selected("")
	UI.fade_in(self)
	_update_blocks()


func _update_blocks() -> void:
	await get_tree().process_frame
	touch.edit_block = [panel.get_global_rect()]


var _panel_bottom := false


## Переносить панель редактора вгору/вниз, щоб не закривала кнопки.
func _move_panel() -> void:
	_panel_bottom = not _panel_bottom
	if _panel_bottom:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
		panel.offset_bottom = -8
		panel.offset_top = -8 - panel.get_combined_minimum_size().y
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
		panel.offset_top = 8
		panel.offset_bottom = 8 + panel.get_combined_minimum_size().y
	panel.offset_left = -330
	panel.offset_right = 330
	_update_blocks()


func _sync_profiles() -> void:
	for i in prof_btns.size():
		prof_btns[i].button_pressed = i + 1 == profile


func _set_profile(n: int) -> void:
	profile = n
	Settings.set_value("controls", "hud_profile", n)
	touch.load_layout(n)
	backup = touch.layout.duplicate(true)
	_sync_profiles()
	_on_selected(touch.edit_sel)


func _on_selected(id: String) -> void:
	_syncing = true
	var on := id != ""
	size_s.editable = on
	alpha_s.editable = on
	vis_b.disabled = not on
	if on:
		name_lbl.text = String(touch.ELEMENT_NAMES.get(id, id))
		size_s.value = float(touch.el(id).get("s", 1.0))
		alpha_s.value = touch.el_alpha(id)
		vis_b.text = "Показати" if touch.el_hidden(id) else "Сховати"
	else:
		name_lbl.text = "Торкніться елемента, щоб змінити його"
		size_s.value = 1.0
		alpha_s.value = 1.0
	size_v.text = "%d%%" % int(size_s.value * 100.0)
	alpha_v.text = "%d%%" % int(alpha_s.value * 100.0)
	_syncing = false


func _on_size(x: float) -> void:
	size_v.text = "%d%%" % int(x * 100.0)
	if not _syncing and touch.edit_sel != "":
		touch.set_el(touch.edit_sel, "s", x)


func _on_alpha(x: float) -> void:
	alpha_v.text = "%d%%" % int(x * 100.0)
	if not _syncing and touch.edit_sel != "":
		touch.set_el(touch.edit_sel, "a", x)


func _toggle_vis() -> void:
	var id: String = touch.edit_sel
	if id == "":
		return
	touch.set_el(id, "h", not touch.el_hidden(id))
	_on_selected(id)


func _reset_el() -> void:
	var id: String = touch.edit_sel
	if id == "":
		return
	touch.layout.erase(id)
	touch.queue_redraw()
	_on_selected(id)


func _save() -> void:
	touch.save_layout(profile)
	Settings.set_value("controls", "hud_profile", profile)
	main.show_hint("Розкладку HUD збережено (профіль %d)" % profile)
	_close()


func _cancel() -> void:
	touch.layout = backup.duplicate(true)
	touch.queue_redraw()
	_close()


func _reset_all() -> void:
	touch.layout = {}
	touch.queue_redraw()
	_on_selected(touch.edit_sel)


func _test() -> void:
	testing = true
	touch.edit_mode = false
	touch.edit_block = []
	touch.reset_input()
	panel.hide()
	test_btn.show()


func _end_test() -> void:
	testing = false
	touch.edit_mode = true
	touch.reset_input()
	panel.show()
	test_btn.hide()
	_update_blocks()


## Кнопка «Назад» на Android: з перевірки — назад до редагування, інакше «Скасувати».
func back() -> void:
	if testing:
		_end_test()
	else:
		_cancel()


func _close() -> void:
	touch.edit_mode = false
	touch.edit_sel = ""
	touch.edit_block = []
	touch.reset_input()
	UI.fade_out(self)
	main.on_hud_editor_closed()
