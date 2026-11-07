extends RefCounted
## Спільні елементи інтерфейсу в тактичному стилі: темні напівпрозорі панелі,
## кнопки з акцентною смугою, заголовки, повзунки. Використовуються в меню і в грі.

const ACCENT := Color(0.86, 0.74, 0.32)
const PANEL := Color(0.04, 0.06, 0.05, 0.84)
const TEXT := Color(0.92, 0.92, 0.88)
const DIM := Color(0.62, 0.65, 0.6)


static func box(col: Color = PANEL, border: Color = Color(1, 1, 1, 0.08), radius: int = 6, bw: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box())
	return p


static func label(text: String, size: int = 20, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func title(text: String, size: int = 30) -> Label:
	var l := label(text, size, ACCENT)
	return l


## Кнопка з темним тлом і акцентною смугою зліва.
static func button(text: String, size: int = 22, min_h: float = 58.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.1, 0.08))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	var n := box(Color(0.07, 0.09, 0.08, 0.86), Color(1, 1, 1, 0.1))
	n.border_width_left = 4
	n.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)
	var h := box(Color(0.12, 0.15, 0.12, 0.92), ACCENT)
	h.border_width_left = 4
	var p := box(ACCENT, ACCENT)
	var d := box(Color(0.06, 0.06, 0.06, 0.6), Color(1, 1, 1, 0.05))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(0, min_h)
	return b


## Велика кнопка дії (ПОЧАТИ, ПІДТВЕРДИТИ).
static func action_button(text: String, size: int = 30) -> Button:
	var b := button(text, size, 74.0)
	var n := box(Color(0.72, 0.6, 0.18, 0.95), Color(1, 0.9, 0.5), 6, 2)
	var h := box(Color(0.85, 0.72, 0.26, 1.0), Color(1, 0.95, 0.6), 6, 2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_color_override("font_color", Color(0.08, 0.08, 0.06))
	b.add_theme_color_override("font_hover_color", Color(0, 0, 0))
	return b


static func slider(minv: float, maxv: float, step: float, val: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(260, 36)
	s.focus_mode = Control.FOCUS_NONE
	return s


## Плавна поява/зникнення панелі (без паузи гри).
static func fade_in(c: CanvasItem, t: float = 0.18) -> void:
	c.modulate.a = 0.0
	c.show()
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, t)


static func fade_out(c: CanvasItem, t: float = 0.15) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, t)
	tw.tween_callback(c.hide)
