extends CanvasLayer

const MAIN_GAME_SCENE_PATH = "res://scenes/world.tscn"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var play_btn = get_node_or_null("VBoxContainer/PlayButton")
	var quit_btn = get_node_or_null("VBoxContainer/QuitButton")
	
	if play_btn and not play_btn.pressed.is_connected(_on_play_button_pressed):
		play_btn.pressed.connect(_on_play_button_pressed)
		
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit_button_pressed):
		quit_btn.pressed.connect(_on_quit_button_pressed)

func _on_play_button_pressed():
	print("Spouštím hru...")
	get_tree().change_scene_to_file(MAIN_GAME_SCENE_PATH)

func _on_quit_button_pressed():
	print("Zavírám hru...")
	get_tree().quit()
