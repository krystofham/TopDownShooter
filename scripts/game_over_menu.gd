extends CanvasLayer
const MAIN_GAME_SCENE_PATH = "res://scenes/world.tscn"

# Nastaví se zvenčí (z world.gd) ještě před přidáním do stromu scény
var is_victory: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	_setup_result_label()
	
	var play_btn = get_node_or_null("VBoxContainer/PlayButton")
	var quit_btn = get_node_or_null("VBoxContainer/QuitButton")
	var play_Ranked_btn = get_node_or_null("VBoxContainer/PlayRankedButton")
	var play_Short_btn = get_node_or_null("VBoxContainer/PlayShort")
	if play_btn and not play_btn.pressed.is_connected(_on_play_button_pressed):
		play_btn.pressed.connect(_on_play_button_pressed)
	if play_Ranked_btn and not play_Ranked_btn.pressed.is_connected(_on_play_button_pressed):
		play_Ranked_btn.pressed.connect(_on_play_ranked_button_pressed)
	play_Short_btn.pressed.connect(_on_play_short_button_pressed)
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit_button_pressed):
		quit_btn.pressed.connect(_on_quit_button_pressed)	

		
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit_button_pressed):
		quit_btn.pressed.connect(_on_quit_button_pressed)

func _setup_result_label():
	var vbox = get_node_or_null("VBoxContainer")
	var result_label = get_node_or_null("VBoxContainer/ResultLabel")
	
	# Pokud label ve scéně ještě neexistuje, vytvoříme ho dynamicky
	if not result_label and vbox:
		result_label = Label.new()
		result_label.name = "ResultLabel"
		result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result_label.add_theme_font_size_override("font_size", 32)
		vbox.add_child(result_label)
		vbox.move_child(result_label, 0)
	
	if result_label:
		if is_victory:
			result_label.text = "VÝHRA"
		else:
			result_label.text = "PROHRA"

func _on_play_button_pressed():
	print("Přesun do ModeManageru...")
	if has_node("/root/ModeManager"):
		ModeManager.start_match("casual", MAIN_GAME_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(MAIN_GAME_SCENE_PATH)
func _on_play_ranked_button_pressed():
	if has_node("/root/ModeManager"):
		# V ostré verzi zde otevřeš menu Casual/Ranked, 
		# pro teď natvrdo řekneme ModeManageru, ať spustí Casual na naší mapě
		ModeManager.start_match("ranked", MAIN_GAME_SCENE_PATH)
	else:
		# Záložní plán, pokud ještě nemáš Autoload hotový
		get_tree().change_scene_to_file(MAIN_GAME_SCENE_PATH)
func _on_play_short_button_pressed():
	if has_node("/root/ModeManager"):
		# V ostré verzi zde otevřeš menu Casual/Ranked, 
		# pro teď natvrdo řekneme ModeManageru, ať spustí Casual na naší mapě
		ModeManager.start_match("short", MAIN_GAME_SCENE_PATH)
	else:
		# Záložní plán, pokud ještě nemáš Autoload hotový
		get_tree().change_scene_to_file(MAIN_GAME_SCENE_PATH)
func _on_quit_button_pressed():
	print("Ukončuji hru z Game Over menu...")
	get_tree().quit()
