extends CanvasLayer

const MAIN_GAME_SCENE_PATH = "res://scenes/world.tscn"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Propojení tlačítek
	var play_btn = get_node_or_null("MarginContainer/VBoxContainer/PlayButton")
	var quit_btn = get_node_or_null("MarginContainer/VBoxContainer/QuitButton")
	var play_Ranked_btn = get_node_or_null("MarginContainer/VBoxContainer/PlayRankedButton")

	if play_btn and not play_btn.pressed.is_connected(_on_play_button_pressed):
		play_btn.pressed.connect(_on_play_button_pressed)
	if play_Ranked_btn and not play_Ranked_btn.pressed.is_connected(_on_play_button_pressed):
		play_Ranked_btn.pressed.connect(_on_play_ranked_button_pressed)
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit_button_pressed):
		quit_btn.pressed.connect(_on_quit_button_pressed)
	update_player_stats_ui()

func update_player_stats_ui():
	var rank_label = get_node_or_null("MarginContainer/VBoxContainer/RankLabel")
	var rank_icon = get_node_or_null("Texture/RankIcon")
	var rank_progress = get_node_or_null("Rankprogress")
	
	if ModeManager:
		if rank_label:
			rank_label.text = "Rank: " + ModeManager.player_rank
			
		if rank_progress:
			var percent = int(ModeManager.elo) % 100
			print(percent)
			rank_progress.value = percent
		if rank_icon:
			if ResourceLoader.exists(ModeManager.rank_asset_path):
				print("zobrazena ikona")
				rank_icon.texture = load(ModeManager.rank_asset_path)
			else:
				print("Chyba: Obrázek ranku nebyl nalezen na cestě: ", ModeManager.rank_asset_path)

func _on_play_button_pressed():
	print("Přesun do ModeManageru...")
	if has_node("/root/ModeManager"):
		# V ostré verzi zde otevřeš menu Casual/Ranked, 
		# pro teď natvrdo řekneme ModeManageru, ať spustí Casual na naší mapě
		ModeManager.start_match("casual", MAIN_GAME_SCENE_PATH)
	else:
		# Záložní plán, pokud ještě nemáš Autoload hotový
		get_tree().change_scene_to_file(MAIN_GAME_SCENE_PATH)
func _on_play_ranked_button_pressed():
	if has_node("/root/ModeManager"):
		# V ostré verzi zde otevřeš menu Casual/Ranked, 
		# pro teď natvrdo řekneme ModeManageru, ať spustí Casual na naší mapě
		ModeManager.start_match("ranked", MAIN_GAME_SCENE_PATH)
	else:
		# Záložní plán, pokud ještě nemáš Autoload hotový
		get_tree().change_scene_to_file(MAIN_GAME_SCENE_PATH)
func _on_quit_button_pressed():
	print("Zavírám hru...")
	get_tree().quit()
