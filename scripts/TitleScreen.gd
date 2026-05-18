extends Control
##
## Title splash. Shows the home image full-screen. If a saved run exists
## (GameState.has_saved_game()), the primary button reads "CONTINUE" and a
## small "Start a new run" link appears below it. Otherwise it's a single
## "ENTER THE WILD" button.
##

@onready var play_btn: Button = $CenterContainer/VBox/PlayBtn
@onready var new_run_btn: Button = $CenterContainer/VBox/NewRunBtn
@onready var hint: Label = $Hint

func _ready() -> void:
	_refresh_for_save_state()
	play_btn.pressed.connect(_on_primary_pressed)
	new_run_btn.pressed.connect(_on_new_run_pressed)

func _refresh_for_save_state() -> void:
	if GameState.has_saved_game():
		play_btn.text = "CONTINUE"
		new_run_btn.visible = true
		hint.text = "tap CONTINUE to resume your run"
	else:
		play_btn.text = "ENTER THE WILD"
		new_run_btn.visible = false
		hint.text = "click anywhere or press Enter to begin"

func _unhandled_input(event: InputEvent) -> void:
	# Click anywhere on the background, or hit Enter/Space → primary action.
	# (Button clicks are consumed by the Button before reaching here.)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_primary_pressed()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_on_primary_pressed()

func _on_primary_pressed() -> void:
	# CONTINUE if a save exists, else fresh start.
	if GameState.has_saved_game():
		GameState.load_from_disk()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_new_run_pressed() -> void:
	# Wipe the save first so Main starts with a clean GameState. The faction
	# picker will appear on Main _ready because player_faction is empty.
	GameState.delete_saved_game()
	GameState.reset_for_new_run()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
