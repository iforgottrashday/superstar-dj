extends Control
##
## Title splash. Shows the GLOBAL SIEGE home image full-screen.
## Click anywhere or press the Play button to advance to the main game.
##

@onready var play_btn: Button = $CenterContainer/PlayBtn

func _ready() -> void:
	play_btn.pressed.connect(_start_game)

func _unhandled_input(event: InputEvent) -> void:
	# Click anywhere or press Enter/Space to start.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_game()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_start_game()

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
