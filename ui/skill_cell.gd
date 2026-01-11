extends Button
class_name SkillCell

@onready var _icon: TextureRect   = %Icon
@onready var _lv: Label           = %Level
@onready var _delta: Label        = %Delta
@onready var _xp_bar: ProgressBar = $XpBar

var skill_id: StringName = &""

const BTN_SIZE: Vector2 = Vector2(280, 160)
const ICON_PIXELS: int = 160  # visual icon size

func _ready() -> void:
	# Button size in the grid
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_FILL
	custom_minimum_size   = BTN_SIZE

	# Icon
	if _icon:
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Setup XP bar
	if _xp_bar:
		_xp_bar.min_value = 0.0
		_xp_bar.max_value = 1.0
		_xp_bar.value = 1.0  # 🔍 force full for now so you can SEE it
		_xp_bar.show_percentage = false
		_xp_bar.mouse_filter = MOUSE_FILTER_IGNORE

		# Anchor it to the bottom of the button
		_xp_bar.anchor_left = 0.0
		_xp_bar.anchor_right = 1.0
		_xp_bar.anchor_top = 1.0
		_xp_bar.anchor_bottom = 1.0

		# Insets: full width, ~8 px tall
		_xp_bar.offset_left = 4
		_xp_bar.offset_right = -4
		_xp_bar.offset_top = -10
		_xp_bar.offset_bottom = -2

		# Red background
		var bg: StyleBoxFlat = StyleBoxFlat.new()
		bg.bg_color = Color(0.3, 0.0, 0.0)
		_xp_bar.add_theme_stylebox_override("background", bg)

		# Green fill
		var fg: StyleBoxFlat = StyleBoxFlat.new()
		fg.bg_color = Color(0.0, 0.7, 0.0)
		_xp_bar.add_theme_stylebox_override("fill", fg)

func set_data(
	id: String,
	_skill_name: String,
	skill_icon: Texture2D,
	level: int,
	delta: int,
	xp_frac: float = 0.0  # ✅ extra param, default 0
) -> void:
	skill_id = id

	# --- ICON: shrink the texture itself to a fixed size ---
	if _icon and skill_icon:
		var img: Image = skill_icon.get_image()
		if img:
			var img_copy: Image = img.duplicate()  # avoid mutating the original
			img_copy.resize(ICON_PIXELS, ICON_PIXELS, Image.INTERPOLATE_NEAREST)
			var small_tex: ImageTexture = ImageTexture.create_from_image(img_copy)
			_icon.texture = small_tex

	# --- LEVEL label ---
	if _lv:
		_lv.text = "Lv %d" % level

	# --- DELTA label ---
	if _delta:
		if delta == 0:
			_delta.visible = false
		else:
			_delta.visible = true
			_delta.text = ("%+d" % delta)

	# --- XP bar ---
	if _xp_bar:
		_xp_bar.value = clamp(xp_frac, 0.0, 1.0)


func set_highlight(on: bool) -> void:
	modulate = (Color(1, 1, 1) if on else Color(0.95, 0.95, 0.95))
