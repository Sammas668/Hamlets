# EscMenu.gd
extends PanelContainer
class_name EscMenu

signal save_requested
signal load_requested
signal settings_requested
signal main_menu_requested
signal quit_requested

# Dimmer is a sibling of PauseMenu
@onready var dim: ColorRect = get_node_or_null("../DimPause") as ColorRect

# Safe lookups (return null if not a Button)
@onready var resume_btn: Button   = get_node_or_null("VBox/ResumeButton")   as Button
@onready var save_btn: Button     = get_node_or_null("VBox/SaveButton")     as Button
@onready var load_btn: Button     = get_node_or_null("VBox/LoadButton")     as Button
@onready var settings_btn: Button = get_node_or_null("VBox/SettingsButton") as Button
@onready var menu_btn: Button     = get_node_or_null("VBox/MainMenuButton") as Button
@onready var quit_btn: Button     = get_node_or_null("VBox/QuitButton")     as Button

func _ready() -> void:
	hide()

	if is_instance_valid(dim):
		dim.visible = false
		dim.mouse_filter = Control.MOUSE_FILTER_STOP  # modal blocker

	# Sanity checks help catch misnamed nodes quickly
	assert(resume_btn  != null, "ResumeButton not found under VBox or is not a Button.")
	assert(save_btn    != null, "SaveButton not found under VBox or is not a Button.")
	assert(load_btn    != null, "LoadButton not found under VBox or is not a Button.")
	assert(settings_btn!= null, "SettingsButton not found under VBox or is not a Button.")
	assert(menu_btn    != null, "MainMenuButton not found under VBox or is not a Button.")
	assert(quit_btn    != null, "QuitButton not found under VBox or is not a Button.")

	resume_btn.pressed.connect(_on_resume)
	save_btn.pressed.connect(func(): emit_signal("save_requested"))
	load_btn.pressed.connect(func(): emit_signal("load_requested"))
	settings_btn.pressed.connect(func(): emit_signal("settings_requested"))
	menu_btn.pressed.connect(func(): emit_signal("main_menu_requested"))
	quit_btn.pressed.connect(func(): emit_signal("quit_requested"))

func open_menu() -> void:
	visible = true
	if resume_btn:
		resume_btn.grab_focus()

func close_menu() -> void:
	visible = false


func _on_resume() -> void:
	close_menu()
